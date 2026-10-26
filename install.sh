#!/usr/bin/env bash
# Installs ca to ~/.local/bin (Linux and macOS). Run it again to update.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="${CA_BIN:-$HOME/.local/bin}"

mkdir -p "$target"
cp "$here/ca" "$target/ca"
chmod +x "$target/ca"

echo "Installed $target/ca"
case ":$PATH:" in
  *":$target:"*) echo "Run: ca add <name>" ;;
  *)
    echo "$target is not on your PATH yet. Add this line to ~/.bashrc or ~/.zshrc, then open a new terminal:"
    echo "  export PATH=\"$target:\$PATH\""
    ;;
esac
