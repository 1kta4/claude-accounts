#!/usr/bin/env bash
# Runs ca against a throwaway home folder and a stand-in `claude`.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT

export CA_HOME="$sandbox/home"
export XDG_DATA_HOME="$sandbox/home/.local/share"
mkdir -p "$CA_HOME/.claude/skills/demo" "$sandbox/bin"
echo demo >"$CA_HOME/.claude/skills/demo/SKILL.md"
echo '{"a":1}' >"$CA_HOME/.claude/settings.json"
printf '{\n  "oauthAccount": {\n    "accountUuid": "x",\n    "emailAddress": "main@example.com"\n  }\n}\n' >"$CA_HOME/.claude.json"

# The stand-in records which folder it was started with.
cat >"$sandbox/bin/claude" <<EOF
#!/usr/bin/env bash
echo "\${CLAUDE_CONFIG_DIR:-unset} \$*" >>"$sandbox/calls"
EOF
chmod +x "$sandbox/bin/claude"
export PATH="$sandbox/bin:$PATH"

ca="$root/ca"
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "ok - $*"; }

"$ca" add work --no-login >/dev/null
acct="$CA_HOME/.claude-accounts/work"
[ -L "$acct/skills" ] || fail "skills is not a link"
[ -f "$acct/skills/demo/SKILL.md" ] || fail "shared skill not visible"
if [ ! -f "$acct/settings.json" ] || [ -L "$acct/settings.json" ]; then fail "settings.json not copied"; fi
ok "add links folders and copies settings"

if [ "$(uname -s)" = Darwin ]; then
  [ -x "$CA_HOME/Applications/Claude accounts/Claude (work).command" ] || fail "no .command shortcut"
else
  grep -q 'Name=Claude (work)' "$XDG_DATA_HOME/applications/claude-account-work.desktop" || fail "no .desktop shortcut"
fi
ok "add makes a shortcut"

"$ca" work -c
grep -q "^$acct -c$" "$sandbox/calls" || fail "claude not started on the work folder: $(cat "$sandbox/calls")"
"$ca" main --version
grep -q "^unset --version$" "$sandbox/calls" || fail "main did not clear CLAUDE_CONFIG_DIR"
ok "runs claude on the right folder"

sleep 1
echo '{"a":2}' >"$acct/settings.json"
"$ca" work --version
grep -q '"a":2' "$CA_HOME/.claude/settings.json" || fail "newer account settings did not reach main"
ok "settings sync back, newest wins"

out="$("$ca" list)"
echo "$out" | grep -q 'main@example.com' || fail "list misses the main email: $out"
echo "$out" | grep -q '^work ' || fail "list misses work: $out"
ok "list shows accounts and emails"

"$ca" add 'bad name' --no-login 2>/dev/null && fail "accepted a bad name"
"$ca" nobody 2>/dev/null && fail "started an unknown account"
"$ca" add add --no-login 2>/dev/null && fail "accepted a reserved name"
ok "refuses bad, unknown and reserved names"

"$ca" remove work --yes >/dev/null
[ ! -e "$acct" ] || fail "account folder still there"
[ -f "$CA_HOME/.claude/skills/demo/SKILL.md" ] || fail "remove reached into ~/.claude"
ok "remove deletes the account and keeps main"

echo "all passed"
