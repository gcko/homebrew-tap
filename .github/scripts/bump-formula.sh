#!/usr/bin/env bash
# Helpers for .github/workflows/bump.yml. Every value that reaches a URL, a path,
# a branch name or the formula is validated here first, and nothing from the
# GitHub API is ever passed to a shell as code.
#
#   bump-formula.sh release-version RELEASE_JSON  print X.Y.Z of a published, stable release
#   bump-formula.sh formula-version FORMULA       print X.Y.Z the formula's url points at
#   bump-formula.sh valid-version VERSION         exit 0 only if VERSION is a plain X.Y.Z
#   bump-formula.sh newer A B                     exit 0 only if version A is newer than B
#   bump-formula.sh checksum VERSION              download the tag tarball, print its sha256
#   bump-formula.sh rewrite FORMULA VERSION SHA   set url and sha256 in the formula
set -euo pipefail

REPO_URL="https://github.com/gcko/Cortado"
VERSION_RE='^[0-9]+\.[0-9]+\.[0-9]+$'
SHA_RE='^[0-9a-f]{64}$'

die() { echo "bump-formula: $*" >&2; exit 1; }

valid_version() {
  [[ "${1-}" =~ $VERSION_RE ]] || die "not a plain X.Y.Z version"
}

valid_sha() {
  [[ "${1-}" =~ $SHA_RE ]] || die "not a lowercase sha256"
}

cmd_release_version() {
  local file="${1-}" draft prerelease tag
  [ -f "$file" ] || die "release file not found"
  draft="$(jq -r '.draft' "$file")"
  prerelease="$(jq -r '.prerelease' "$file")"
  tag="$(jq -r '.tag_name' "$file")"
  [ "$draft" = "false" ] || die "latest release is a draft"
  [ "$prerelease" = "false" ] || die "latest release is a prerelease"
  [[ "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]] || die "release tag is not vX.Y.Z"
  echo "${BASH_REMATCH[1]}"
}

cmd_formula_version() {
  local formula="${1-}" urls
  [ -f "$formula" ] || die "formula not found"
  urls="$(grep -c '^  url "' "$formula" || true)"
  [ "$urls" = "1" ] || die "expected exactly one top-level url line, found $urls"
  local line
  line="$(grep '^  url "' "$formula")"
  [[ "$line" =~ ^\ \ url\ \"https://github\.com/gcko/Cortado/archive/refs/tags/v([0-9]+\.[0-9]+\.[0-9]+)\.tar\.gz\"$ ]] \
    || die "formula url is not a Cortado tag tarball"
  echo "${BASH_REMATCH[1]}"
}

cmd_newer() {
  local a="${1-}" b="${2-}" i
  valid_version "$a"
  valid_version "$b"
  local -a pa pb
  IFS=. read -r -a pa <<<"$a"
  IFS=. read -r -a pb <<<"$b"
  for i in 0 1 2; do
    # 10# stops a leading zero from reading as octal.
    if ((10#${pa[$i]} > 10#${pb[$i]})); then return 0; fi
    if ((10#${pa[$i]} < 10#${pb[$i]})); then return 1; fi
  done
  return 1
}

cmd_checksum() {
  local version="${1-}" dir
  valid_version "$version"
  dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" EXIT
  curl --fail --silent --show-error --location \
    --proto '=https' --proto-redir '=https' \
    --retry 3 --max-time 180 --max-filesize 52428800 \
    --output "$dir/src.tar.gz" \
    "$REPO_URL/archive/refs/tags/v$version.tar.gz"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$dir/src.tar.gz" | cut -d' ' -f1
  else
    shasum -a 256 "$dir/src.tar.gz" | cut -d' ' -f1
  fi
}

cmd_rewrite() {
  local formula="${1-}" version="${2-}" sha="${3-}" tmp
  [ -f "$formula" ] || die "formula not found"
  valid_version "$version"
  valid_sha "$sha"
  [ "$(grep -c '^  url "' "$formula" || true)" = "1" ] || die "expected exactly one top-level url line"
  [ "$(grep -c '^  sha256 "' "$formula" || true)" = "1" ] || die "expected exactly one top-level sha256 line"
  cmd_formula_version "$formula" >/dev/null
  tmp="$(mktemp)"
  awk -v url="  url \"$REPO_URL/archive/refs/tags/v$version.tar.gz\"" \
      -v sha="  sha256 \"$sha\"" '
    /^  url "/    { print url; next }
    /^  sha256 "/ { print sha; next }
    { print }
  ' "$formula" >"$tmp"
  cat "$tmp" >"$formula"
  rm -f "$tmp"
  [ "$(cmd_formula_version "$formula")" = "$version" ] || die "rewrite did not take"
  grep -q "^  sha256 \"$sha\"\$" "$formula" || die "rewrite did not take"
}

case "${1-}" in
  release-version) shift; cmd_release_version "$@" ;;
  formula-version) shift; cmd_formula_version "$@" ;;
  valid-version)   shift; valid_version "$@" ;;
  newer)           shift; cmd_newer "$@" ;;
  checksum)        shift; cmd_checksum "$@" ;;
  rewrite)         shift; cmd_rewrite "$@" ;;
  *) die "usage: bump-formula.sh release-version|formula-version|valid-version|newer|checksum|rewrite ..." ;;
esac
