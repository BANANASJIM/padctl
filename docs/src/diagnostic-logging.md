# Diagnostic Logging

padctl ships with a general-purpose, togglable file logger. It is designed to be the single mechanism you reach for when diagnosing **any** class of bug — stuck rumble, input drops, mapping misses, hotplug oddities, daemon crashes — so that reports come with structured evidence instead of guesswork.

It is **off by default** and has no hot-path cost when disabled. The current build already emits a very detailed trace of the force-feedback pipeline; other subsystems (input routing, layer/remap decisions, hotplug, config reload, …) will be instrumented behind the same switch over time. The user-facing contract — enable, reproduce, export, attach — stays the same as more coverage is added.

## Quick workflow

```sh
padctl dump enable                          # turn logging on (survives reboot)
# ... reproduce the issue by playing ...
padctl dump export --period 30m -o bug.log  # capture the last 30 minutes
padctl dump disable                         # turn it off again
```

Attach `bug.log` to your issue report.

## Commands

| Command | Description |
|---------|-------------|
| `padctl dump enable` | Turn diagnostic logging on. Persists across restarts by writing `[diagnostics].dump = true` to the user config (and `/etc/padctl/config.toml` via `sudo` when available). Also sends a live IPC to any running daemon so the change takes effect immediately. |
| `padctl dump disable` | Turn diagnostic logging off (default state). Same persistence semantics as `enable`. |
| `padctl dump status` | Print current state (`enabled` / `disabled`), the active log path, log file size, oldest/newest entry timestamps, and the rotated backup size if present. |
| `padctl dump export --period <N>m\|<N>h\|<N>d [-o path]` | Export the window of log lines newer than the given duration. `-o` writes to a file; omit it to print to stdout. Default window: `1d`. |
| `padctl dump clear` | Delete the live log and any rotated backups. Asks for confirmation. Falls back to `sudo rm` for root-owned logs when the CLI user can't unlink them directly. |

### Period syntax

`--period` accepts `Nm` (minutes), `Nh` (hours), or `Nd` (days). Examples: `--period 15m`, `--period 2h`, `--period 7d`.

## Log file location

padctl picks the first entry whose env var is set / parent dir is
reachable, going top-to-bottom:

| Priority | Path | Source |
|----------|------|--------|
| 1 | `$STATE_DIRECTORY/padctl.log` | Set by systemd when the unit declares `StateDirectory=padctl`. Resolves to `$XDG_STATE_HOME/padctl/` on the user service (default `~/.local/state/padctl/`) and `/var/lib/padctl/` on a system service. |
| 2 | `$XDG_STATE_HOME/padctl/padctl.log` | Non-systemd invocations (e.g. the CLI running in the user's shell) with `$XDG_STATE_HOME` set. |
| 3 | `~/.local/state/padctl/padctl.log` | XDG fallback when `$XDG_STATE_HOME` is unset but `$HOME` is. |
| 4 | `/var/log/padctl/padctl.log` | Last-resort fallback when neither `$HOME` nor `$XDG_STATE_HOME` is available. |

On a default Bazzite install (user-service + `StateDirectory=padctl` in
the unit file) the daemon and CLI both converge on
`~/.local/state/padctl/padctl.log`.

`padctl dump status` prints the path currently in use. If both the
current-session path and a legacy location contain `padctl.log`, the
command picks whichever file was most recently modified (mtime-based)
so you always see the active one.

## Config file

Diagnostic logging is driven by a dedicated section in `config.toml`:

```toml
[diagnostics]
dump = false          # master switch; padctl dump enable/disable flips this
max_log_size_mb = 100 # rotation threshold (default 100 MB)
```

`padctl dump enable` and `padctl dump disable` are just a convenience front-end for toggling `dump` and forwarding the change to the running daemon — you can also edit this section by hand and send `SIGHUP` (`padctl reload`) instead.

> ⚠️ **Rewrite behavior.** `padctl dump enable/disable` parses `config.toml`, rewrites it from the known schema, and atomically renames the result into place. Anything outside the documented schema — unknown sections, undocumented keys, hand-written comments — is **not preserved**. If you hand-edit `config.toml` with content that matters (e.g. a forward-looking `[experimental]` block, inline comments documenting a choice), keep it in a sibling file, or drive padctl via `SIGHUP` after the edit instead of using the `dump` subcommand. The current known schema is `version`, `[diagnostics]` (`dump`, `max_log_size_mb`), and `[[device]]` entries (`name`, `default_mapping`).

## Rotation

On every daemon startup and on every fresh file-open, padctl stats the existing log. If it exceeds `max_log_size_mb`, the file is renamed to `padctl.log.1` (overwriting any previous backup) and a new empty `padctl.log` is created. There is only ever one rotated backup.

This keeps disk usage bounded to roughly `2 * max_log_size_mb` without needing `logrotate` or any external tooling.

## What gets logged

When `dump = false` (the default), only warnings and errors are written, and only lazily on the first occurrence.

When `dump = true`, padctl adds verbose tracing on top. The coverage today is deepest in the force-feedback pipeline — that is the area where the logger was needed first — and is being expanded to other subsystems as issues surface. Current coverage:

- **Session lifecycle** — daemon start, config loaded, devices attached/detached
- **FF_UPLOAD / FF_ERASE** kernel requests with effect IDs, rumble magnitudes, and replay durations
- **EV_FF PLAY / STOP** events with scheduler decisions (forwarded, throttled, auto-stop timer armed, etc.)
- **HID rumble frames** written to the physical device, with the first 16 bytes hex-dumped so post-checksum data can be inspected
- **Scheduler slot state** (all 16 effect slots) before and after every mutation

Planned areas (no promised order): input-report parsing, layer/remap resolution, hotplug/netlink events, config reload, IPC commands. You can track progress on these in the repo issue tracker.

## Reporting issues

When opening an issue that needs diagnostic data, the recommended flow is:

```sh
padctl dump enable
# reproduce the bug (play the game, press the button, wait for the glitch)
padctl dump export --period 1h -o issue.log
padctl dump disable
```

Attach `issue.log`. Sensitive information in the logs is limited to device names, USB identifiers, and input report bytes — there is no keystroke capture or payload from other applications.
