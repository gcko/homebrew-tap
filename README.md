# gcko/homebrew-tap

Homebrew formulas for [Cortado](https://github.com/gcko/Cortado), a statusline for Claude Code.

## Install

```bash
brew install gcko/tap/cortado
cortado setup
```

Restart Claude Code afterwards. `cortado setup` points Claude Code's `statusLine` at Homebrew's stable `opt` path, so it keeps working after `brew upgrade`. Run `cortado doctor` to check the install.

Homebrew asks you to trust a tap that is not its own. Installing by the full name, as above, trusts only the Cortado formula.

Cortado needs `jq` (installed as a dependency) and Perl (macOS includes it; Homebrew installs it on Linux).

## Upgrade

```bash
brew update
brew upgrade cortado
```

Your settings survive upgrades. Cortado keeps them in your Claude config directory (`~/.claude`, or `$CLAUDE_CONFIG_DIR` if you set it): `cortado.conf`, `settings.json` and the cache, outside the Homebrew keg, and Homebrew only replaces the program files. Restart Claude Code to run the new version.

`cortado update` does nothing on a Homebrew install except tell you to run `brew upgrade cortado`.

## Uninstall

```bash
cortado uninstall
brew uninstall cortado
```

`cortado uninstall` restores the statusline you had before Cortado (or removes Cortado's `statusLine` if there was none) and deletes none of the program files. `brew uninstall cortado` then removes the program. Run them in this order, so Claude Code is not left pointing at a program that is gone.

## Development

Pull requests run `brew install --build-from-source`, `brew test`, `brew audit --strict --online` and `brew style` on macOS and Linux (`.github/workflows/tests.yml`).
