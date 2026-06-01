# Power consumption & management

Notes on battery/power behaviour for this workstation. Companion to the
deeper niri/compositor notes in `~/Sync/docs/claude_workdirs/hyprland/niri.md`
("Troubleshooting: niri high CPU").

## Hardware

- **CPU:** AMD Ryzen 7 PRO 6850U (8 cores / 16 threads, Zen3+ "Rembrandt")
- **GPU:** integrated Radeon 680M (same die; no discrete GPU)
- **Display:** eDP-1, 1920x1200 @ 60 Hz
- **Battery:** ~46.5 Wh design, 363 cycles as of 2026-06-01

## The power stack (what's in charge)

- **`power-profiles-daemon` (PPD)** is the single power manager — profile
  is `balanced` by default. It drives *both* the CPU
  energy-performance-preference (via `amd_pstate`) and the ACPI
  `platform_profile` together.
- **`amd-pstate-epp`** in **active** mode is the cpufreq driver; governor
  `powersave`, EPP `balance_performance`. (On AMD, "powersave" is the
  normal hardware-managed P-state governor — it is *not* a low-power
  lock; the EPP hint does the balancing.)
- **No TLP.** Intentional — TLP and PPD both manage the same knobs and
  conflict. PPD is the chosen stack (it also backs the noctalia/waybar
  power-profile widget). Do **not** install TLP alongside it.

PPD profiles → `platform_profile`:

| PPD profile  | platform_profile | use                         |
| ---          | ---              | ---                         |
| `power-saver`| `low-power`      | max battery, on the go      |
| `balanced`   | `balanced`       | default                     |
| `performance`| `performance`    | plugged in, heavy work      |

Switch with `powerprofilesctl set <profile>` (or the bar widget — see
the hyprland CLAUDE.md, `custom/cpu` / power-profiles module).

## Measuring power draw

Battery discharge can only be read **on battery** (on AC, `power_now`
reflects *charging* watts, not consumption):

```sh
# Live discharge in watts (unplug first):
upower -i $(upower -e | grep BAT) | grep -E 'state|energy-rate'
# or raw:
cat /sys/class/power_supply/BAT0/power_now   # microwatts
```

- `powertop` is installed — `sudo powertop` for per-device/per-process
  power estimates and the **Tunables** tab. `sudo powertop --auto-tune`
  applies all recommended tunables for the current boot (not persistent).
- Per-process wakeups (a proxy for power) without root:
  voluntary ctxt-switches/sec from `/proc/<pid>/status`.

## What actually moves the needle (this machine, biggest first)

1. **Display backlight** — by far the largest single consumer. Was at
   **100%** (`/sys/class/backlight/amdgpu_bl1`, 64764/64764) during
   investigation. Dropping brightness saves more than any CPU tweak.
   `brightnessctl set 40%` is the quickest win on battery.
2. **CPU kept awake by continuous redraws.** See the niri finding below —
   an animated TUI / live web content forces the compositor to
   recomposite at 60 Hz, pinning a core and preventing deep C-states.
3. **PPD profile** — `power-saver` caps the EPP toward efficiency; worth
   setting when unplugged and not doing heavy work.

## Compositor / redraw cost (learned 2026-06-01)

A Wayland compositor (niri) burns CPU — and therefore power — recompositing
on **every frame a visible client damages**, up to 60 Hz. Continuous-redraw
clients (animated TUIs like Claude Code in kitty, live dashboards, video,
tracking maps) hold the CPU busy and block idle. Observed: niri ~15–25%
of one thread while such a client was focused, vs ~1% on an empty
workspace. On a 6850U that sustained load is roughly a watt-plus of extra
draw and lost C-state residency.

Mitigations already applied (see `dotfiles/kitty/kitty.conf` and the
niri.md troubleshooting section):

- `repaint_delay 33` (~30 fps cap — at 60 Hz, values ≤16 do nothing),
  `cursor_blink_interval 0`, `input_delay 5`, `wayland_enable_ime no` →
  niri ~15% → ~10% with a streaming TUI focused.
- **VRR does not help** continuous-redraw clients (they submit frames at
  full rate regardless). `variable-refresh-rate on-demand=true` is set on
  eDP-1 only for fullscreen video/games.
- Practical habit: don't leave animated content (live maps, auto-refresh
  Grafana, video) on the *focused/visible* workspace when on battery —
  off-screen clients are cheap, focused animated ones are not.

## Untapped knobs (not changed, candidates if chasing battery)

- **PCIe ASPM** is at `[default]` (`/sys/module/pcie_aspm/parameters/policy`);
  `powersave` can cut idle draw. Set via kernel param
  `pcie_aspm.policy=powersave` (test for stability).
- **`nmi_watchdog=1`** — powertop flags this; `echo 0 >
  /proc/sys/kernel/nmi_watchdog` (or `kernel.nmi_watchdog=0` in sysctl)
  saves a little.
- `background_opacity 0.8` in kitty forces per-frame alpha-blend in niri;
  opaque (`1.0`) would trim compositor work. Untested.
- **foot** terminal (CPU-rendered) is lighter on the compositor for
  animated TUIs than a GPU terminal re-blitting every frame.

## Intentionally not done

- No TLP (conflicts with PPD — see above).
- No undervolting / `ryzenadj` — stock is stable; not worth the risk.
- No auto-applied powertop tunables at boot — kept manual/opt-in.
