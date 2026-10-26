# claude-accounts

Run Claude Code on as many accounts as you like (work, personal, a client) on one machine, on Windows, macOS or Linux, and switch with one command or one click. Every account logs in **once**, and they all share your skills, plugins, mods, memory, chat history and settings.

```
ca add work          # makes the account and opens the login, the only time you log in
ca add personal
ca                   # lists accounts and the email each is logged in with
ca work              # starts claude on the work account
ca personal -c       # starts claude on personal and continues its last chat
ca main              # your normal ~/.claude account
ca remove personal   # deletes an account (asks first)
```

Each `ca add` also makes a shortcut, *Claude (work)*, that opens a terminal running Claude on that account:

| System | Shortcut | Options |
| --- | --- | --- |
| Windows | Start menu, folder *Claude accounts* | `ca shortcut work -Desktop` adds one on the desktop, `-Folder C:\path\to\project` starts in a project |
| macOS | `~/Applications/Claude accounts/Claude (work).command`: double-click it or drag it to the Dock | `ca shortcut work --folder ~/code/project` |
| Linux | *Claude (work)* in your app menu (a `.desktop` file in `~/.local/share/applications`) | `ca shortcut work --folder ~/code/project` |

## Install

**Windows** (PowerShell):

```powershell
git clone https://github.com/1kta4/claude-accounts
cd claude-accounts
.\install.ps1
```

Then open a new PowerShell window. The installer copies `ca.ps1` to `%LOCALAPPDATA%\claude-accounts` and adds a `ca` command to your PowerShell profile.

**macOS and Linux** (bash):

```bash
git clone https://github.com/1kta4/claude-accounts && cd claude-accounts && ./install.sh
```

The installer copies `ca` to `~/.local/bin` and tells you if that folder still needs to go on your `PATH`. On macOS and Linux the flags are spelled `--no-login`, `--yes` and `--folder`; on Windows they're `-NoLogin`, `-Yes` and `-Folder`.

Run the installer again after a `git pull` to update.

## How it works

Claude Code reads its login and data from the folder named by `CLAUDE_CONFIG_DIR` (default `~/.claude`). `ca` gives each account its own folder, `~/.claude-accounts/<name>`, and sets that variable for the one `claude` it starts. Nothing changes in the shell you ran it from.

What's shared, and how:

| Shared with `~/.claude` | How |
| --- | --- |
| `skills`, `plugins`, `agents`, `commands`, `output-styles`, `hooks`, `projects` (memory and chat history), `plans`, `todos`, `file-history` | Linked, so every account reads the same folder: directory junctions on Windows (no admin rights needed), symbolic links on macOS and Linux. |
| `settings.json`, `settings.local.json`, `CLAUDE.md`, `keybindings.json` | Copied, newest wins, before and after each run. Claude Code saves these by replacing the whole file, which would cut a link. |

What stays per account: the login (`.credentials.json`; on macOS a Keychain item instead), `.claude.json` (which also holds user-level MCP servers and onboarding state) and prompt history. Add user-level MCP servers in each account, or put them in a project's `.mcp.json`.

If two accounts change the same settings file at the same time, the one that exits last wins.

`ca relink <name>` repairs an account whose shared folders got out of place.

## account-badge mod (optional)

Shows `account: work · you@work.com` in the status line and adds an `/account` command that lists your accounts and how to switch. Install it at the prompt of a Claude Code terminal session:

```
/plugin install account-badge --marketplace 1kta4/claude-accounts
```

Since `plugins` and `settings.json` are shared, installing it once at the user scope turns it on in every account. A running session can't change accounts: `/exit`, then `ca <account>`.

## Notes

- Windows needs PowerShell 5.1 or newer; macOS and Linux need bash (the bash 3.2 that ships with macOS works). The Claude desktop app keeps its own login and is not affected.
- **macOS logins:** Claude Code keeps the login in the Keychain, not in a file. Recent versions are reported to keep a separate Keychain item for each config folder, which keeps accounts apart. This hasn't been checked with real logins yet. If one account's login replaces another's, run `claude update` and log in again.
- The bash version is tested on Ubuntu and macOS in CI (`tests/test.sh`) against a stand-in `claude`, not a real login.
- Keeping a work account and a personal account apart is the point here. Rotating accounts to get around usage limits may break Anthropic's terms.

## License

MIT
