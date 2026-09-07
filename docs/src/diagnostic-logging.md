# Diagnostic Logging

padctl ships with a general-purpose, togglable file logger. It is designed to be the single mechanism you reach for when diagnosing **any** class of bug — stuck rumble, input drops, mapping misses, hotplug oddities, daemon crashes — so that reports come with structured evidence instead of guesswork.

It is **off by default**. With dump off the verbose trace lines never reach the
journal or disk — they are held only in the in-memory flight recorder described
below, which persists them when something goes wrong. The
current build emits a detailed trace of the force-feedback pipeline plus button
input edges, gesture decisions, and virtual button output edges; other
subsystems (non-gesture layer/remap decisions, hotplug, config reload, …) will
be instrumented behind the same switch over time. The user-facing contract —
enable, reproduce, export, attach — stays the same as more coverage is added.

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
| `padctl dump status` | Print current state (`enabled` / `disabled`), the flight recorder's buffered line count and last flush, the active log path, log file size, oldest/newest entry timestamps, and the rotated backup size if present. |
| `padctl dump export --period <N>m\|<N>h\|<N>d [-o path]` | Export the window of log lines newer than the given duration. Asks a running daemon to flush its flight recorder first, so the export includes the in-memory window. `-o` writes to a file; omit it to print to stdout. Default window: `1d`. |
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

<a id="schema-rewrite"></a>

> ⚠️ **Rewrite behavior.** `padctl dump enable/disable` parses `config.toml`, rewrites it from the known schema, and atomically renames the result into place. Anything outside the documented schema — unknown sections, undocumented keys, hand-written comments — is **not preserved**. If you hand-edit `config.toml` with content that matters (e.g. a forward-looking `[experimental]` block, inline comments documenting a choice), keep it in a sibling file, or drive padctl via `SIGHUP` after the edit instead of using the `dump` subcommand. The current known schema is `version`, `[diagnostics]` (`dump`, `max_log_size_mb`), `[supervisor]` (`suspend_grace_sec`), `[chord_switch]` (`modifier`, `selectors`, `hold_ms`), and `[[device]]` entries (`name`, `default_mapping`, `output_profile`).

## Supervisor tunables

`config.toml` may also include a `[supervisor]` section to tune hot-plug suspend behavior:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `suspend_grace_sec` | i64 | 15 | Seconds to keep a suspended device alive before transactional rebind, allowing transient disconnects to recover without re-grabbing |

The `suspend_grace_sec` value is preserved across `padctl dump enable/disable` and `padctl switch`; comments and unknown keys inside `[supervisor]` follow the same rewrite caveat as the rest of `config.toml`.

## Chord switch (issue #183)

Set up an in-controller mapping switch so you can change profiles without leaving Big Picture mode. Add a `[chord_switch]` section to `~/.config/padctl/config.toml` and a `chord_index` to each mapping you want to be selectable:

```toml
# ~/.config/padctl/config.toml
[chord_switch]
modifier  = ["LM", "RM"]      # held simultaneously to arm the chord
selectors = ["A", "B", "X", "Y"]  # each maps to chord_index 1..N by position
hold_ms   = 80                # debounce window — selector edges in this window are ignored

# ~/.config/padctl/mappings/fps.toml
name = "fps"
chord_index = 1   # press A while holding modifier → switch to this mapping

# ~/.config/padctl/mappings/racing.toml
name = "racing"
chord_index = 2   # press B while holding modifier → switch to this mapping
```

While the modifier is held, selector buttons are suppressed from the virtual gamepad output so the in-game UI does not see them. If no mapping declares a matching `chord_index`, the daemon logs a warning and does nothing. The standard `padctl switch <name>` CLI still works alongside the chord. `[chord_switch]` is preserved across `padctl dump enable/disable`'s rewrite. Comments inside the section follow the same rewrite caveat as the rest of `config.toml`.

## Rotation

On every daemon startup and on every fresh file-open, padctl stats the existing log. If it exceeds `max_log_size_mb`, the file is renamed to `padctl.log.1` (overwriting any previous backup) and a new empty `padctl.log` is created. There is only ever one rotated backup.

This keeps disk usage bounded to roughly `2 * max_log_size_mb` without needing `logrotate` or any external tooling.

## Flight recorder

Sporadic faults — rumble that will not stop, a dropped rumble write, a
disconnect — tend to happen when nobody had `padctl dump enable` running. The
flight recorder closes that gap: the daemon always keeps the most recent **1024
trace lines** (256 KiB, oldest overwritten first) in memory, even with dump off,
and appends them to `padctl.log` when something goes wrong. Nothing reaches
disk until a trigger fires, so the ring costs no I/O and no disk space during
normal play.

### Triggers

| Reason | Fires when |
|--------|-----------|
| `rumble-stuck` | The newest rumble frame written to the device was non-zero and 10 s passed with no newer frame. Reported once per episode; re-arms after a zero frame is written. |
| `rumble-write-dropped` | A rumble frame exhausted its write retries and was dropped. |
| `disconnect` | The device went away — POLLHUP, a read error, or a write that reported a disconnect. |
| `signal` | `kill -USR1 <daemon pid>` |
| `export` | `padctl dump export` sends this to the running daemon automatically. |
| `shutdown` | The daemon is stopping. |

The three automatic triggers flush at most once every 30 seconds so a repeating
fault cannot fill the disk. `signal`, `export` and `shutdown` always flush.

### Reading the output

A flushed window appears in `padctl.log` between markers:

```
FLIGHT_RECORDER begin reason=rumble-stuck lines=1024
[2026-09-07T04:53:03.384] [MONO:859498771067408] debug(rumble): [Vader 5 Pro] FF_PLAY: id=0 ...
...
FLIGHT_RECORDER end
```

The buffered lines keep their original timestamps, so they are usually older
than the surrounding log. `padctl dump status` reports how many lines are
buffered and when the last flush happened. To capture the current window by
hand, without waiting for a trigger:

```sh
kill -USR1 $(pidof padctl)
```

If the log file cannot be written (for example a root-owned state directory),
the daemon warns once and keeps the ring in memory rather than dropping it.

## What gets logged

When `dump = false` (the default), only warnings and errors are written to the log file, and only lazily on the first occurrence. Verbose trace lines still flow into the flight recorder and reach the file when a trigger fires.

When `dump = true`, padctl adds verbose tracing on top. The coverage today is deepest in the force-feedback pipeline — that is the area where the logger was needed first — and is being expanded to other subsystems as issues surface. Current coverage:

- **Session lifecycle** — daemon start, config loaded, devices attached/detached
- **Button input edges** — the changed decoded button mask and the bounded raw
  controller report that produced it (`INPUT_EDGE`); axis/IMU-only frames are
  intentionally omitted so high-rate devices do not flood the dump
- **Gesture decisions** — physical source edge and press duration, timer
  arm/cancel, emitted action and target, and hold/double timer expiry
  (`GESTURE_EDGE`, `GESTURE_EMIT`, `GESTURE_TIMER`)
- **Virtual button output edges** — the changed mapped button mask and whether
  it came from physical input, the layer timer, or the shared macro/gesture
  timer (`OUTPUT_EDGE`)
- **FF_UPLOAD / FF_ERASE** kernel requests with effect IDs, rumble magnitudes, and replay durations
- **EV_FF PLAY / STOP** events with scheduler decisions (forwarded, throttled, auto-stop timer armed, etc.)
- **HID rumble frames** written to the physical device, with the first 16 bytes hex-dumped so post-checksum data can be inspected
- **Scheduler slot state** (all 16 effect slots) before and after every mutation
- **Rumble write recovery** — retry attempts, retry-limit exhaustion, and whether the input loop stayed alive after a non-disconnect write failure
- **Hotplug/rebind rumble quiesce** — detach, init, re-init, and neutral rumble frames emitted after a fresh physical fd is bound

Planned areas (no promised order): axis/IMU input tracing, non-gesture layer/remap
resolution, hotplug/netlink events, config reload, IPC commands. You can track
progress on these in the repo issue tracker.

## Reporting issues

When opening an issue that needs diagnostic data, the recommended flow is:

```sh
padctl dump enable
# reproduce the bug (play the game, press the button, wait for the glitch)
padctl dump export --period 1h -o issue.log
padctl dump disable
```

Attach `issue.log`. Sensitive information in the logs is limited to device names, USB identifiers, and input report bytes — there is no keystroke capture or payload from other applications.

For button or gesture reports, the most useful lines are `INPUT_EDGE`,
`GESTURE_EDGE`, `GESTURE_EMIT`, `GESTURE_TIMER`, and `OUTPUT_EDGE`. Their
monotonic timestamps let maintainers follow one physical edge through the
gesture decision and into the virtual device.

For stuck-rumble reports, also attach `padctl doctor` output and note the game
action that produced the rumble. The most useful lines are `FF_PLAY`,
`FF_STOP`, `HID_WRITE`, `SCHED`, `DISCONNECT`, and `retry limit exceeded`.
