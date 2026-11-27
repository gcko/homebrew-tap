# frozen_string_literal: true

class Cortado < Formula
  desc "Modular shell statusline for Claude Code CLI"
  homepage "https://github.com/gcko/Cortado"
  url "https://github.com/gcko/Cortado/archive/refs/tags/v2.1.0.tar.gz"
  sha256 "76f742face17edd47edcc0743dcdd51fc25ed5b3718c450da0d8e592a35f69b4"
  license "Apache-2.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "jq"
  uses_from_macos "perl"

  def install
    # Only the runtime. Homebrew owns updates and removal, so install.sh stays
    # behind: `cortado update` and `cortado uninstall` never run it from a keg.
    libexec.install "cortado.sh", "cortado.conf", "VERSION", "modules", "lib"

    # cortado.sh follows symlinks to find modules/ and lib/ (Cortado 2.1.0), so
    # a link works where a wrapper script used to be needed.
    bin.install_symlink libexec/"cortado.sh" => "cortado"

    # Cortado refuses to read a packaged cortado.conf whose directory others
    # can write. Homebrew on Linux installs with a group-writable umask, so
    # take group and world write off everything the keg holds.
    chmod_R "go-w", libexec
  end

  def caveats
    <<~EOS
      Point Claude Code at Cortado once:

        cortado setup

      It writes the stable path #{opt_libexec}/cortado.sh to statusLine in
      ~/.claude/settings.json, so `brew upgrade cortado` never breaks it. Your
      settings in your Claude config directory (~/.claude
      by default) are kept across upgrades. Restart Claude Code
      afterwards, and run `cortado doctor` to check the install.

      Update with `brew upgrade cortado`. Before `brew uninstall cortado`, run
      `cortado uninstall` to restore your previous statusLine.
    EOS
  end

  test do
    assert_path_exists libexec/"modules/utils.sh"
    assert_path_exists libexec/"lib/statusline-settings.sh"
    assert_match version.to_s, shell_output("#{bin}/cortado version")

    help = shell_output("#{bin}/cortado help")
    assert_match "setup", help
    assert_match "doctor", help

    # Everything below runs in a sandboxed config directory, never ~/.claude.
    ENV["CLAUDE_CONFIG_DIR"] = testpath/".claude"
    (testpath/".claude").mkpath

    payload = <<~JSON
      {"workspace":{"current_dir":"#{testpath}"},"model":{"display_name":"Formula Test"},
       "context_window":{"context_window_size":200000,"current_usage":{"input_tokens":10000}}}
    JSON
    line = pipe_output(bin/"cortado", payload)
    assert_match "Formula Test", line
    # A refused or partly read packaged config would put a notice first.
    refute_match "Config refused", line
    refute_match "Config partly read", line

    # setup records the stable opt path, not the versioned Cellar path.
    system bin/"cortado", "setup"
    settings = (testpath/".claude/settings.json").read
    assert_match "#{opt_libexec}/cortado.sh", settings
    refute_match "Cellar", settings

    # Homebrew owns the files: update defers to brew, uninstall only restores
    # the statusLine.
    assert_match "brew upgrade cortado", shell_output("#{bin}/cortado update 2>&1", 1)
    assert_match "brew uninstall cortado", shell_output("#{bin}/cortado uninstall")
    refute_match "statusLine", (testpath/".claude/settings.json").read
  end
end
