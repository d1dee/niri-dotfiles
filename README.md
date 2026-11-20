<div align="center">
    <h1>Fedora niri dotfiles</h1>
</div>

Fedora/niri port of [BnSplit's dotfiles](https://github.com/bnsplits/dotfiles),
with a Quickshell desktop, greetd login screen, and PAM-authenticated lock screen.

## Upstream Preview

The video and screenshots below come from the upstream setup. They illustrate
the shell's visual style, not a verified capture of this Fedora/niri port; some
upstream compositor and capture features have been replaced or removed.

https://github.com/user-attachments/assets/f3fd43bb-1a19-442a-9920-9c2a3e5ce66b

<div align="center">
    <img src="assets/screenshot-1.png" alt="" width="49%">
    <img src="assets/screenshot-2.png" alt="" width="49%">
    <img src="assets/screenshot-3.png" alt="" width="49%">
    <img src="assets/screenshot-4.png" alt="" width="49%">
</div>

> [!NOTE]
> These are my personal dotfiles. `setup` handles the install, but not everything is guaranteed to work unmodified on another machine. Some manual adjustments may be needed.

## Notable features

- Quickshell: bar, launcher, control center, notifications, OSD, lock screen, and greeter
- Launcher pages: apps, files, clipboard (via [bnclip](https://github.com/bnsplits/bnclip)), emojis, calculator, monitors, processes, tasks, translate, commands, web search, and wallpaper pickers (local, Wallhaven, Unsplash); shortcuts use niri's native hotkey overlay
- Wallpaper-driven shell/GTK theming via [bnchroma](https://github.com/bnsplits/bnchroma) + [awww](https://codeberg.org/LGFae/awww)
- Lean GNOME integration: calendar events via Evolution Data Server, additional Control Center settings, and a wallpaper portal for Set as Background
- Native niri screenshot selection, OCR, Lens, and portal-based screen sharing/recording

## Installation

This port targets **niri 26.04 or newer on mutable Fedora with DNF5, x86_64**
(not Silverblue, Kinoite, or other rpm-ostree desktops). Both the desktop and
greeter use niri; Hyprland and its portal/idle/lock utilities are not required.
Package installation, update checks, and package pickers use Fedora/DNF5.

`setup` automatically enables these COPR repositories before refreshing metadata
and checking dependencies:

| COPR | Purpose |
| --- | --- |
| [errornointernet/quickshell](https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell/) | Quickshell release packages, as recommended by upstream |
| [scottames/awww](https://copr.fedorainfracloud.org/coprs/scottames/awww/) | awww wallpaper client and daemon |

If DNF5's COPR command is missing, setup first installs `dnf5-plugins` with `-y`.
COPR enablement also uses `-y`; the main package installation remains interactive,
including any signing-key imports it needs. These repositories remain
enabled for later DNF updates. They are community maintained, not supported by
Fedora; review them before running setup.

niri and the remaining required desktop packages are resolved from enabled
repositories, including Fedora's normal repositories. Setup does not enable a
Hyprland COPR or force packages from another Fedora release. Repository/plugin
failures stop installation; partial repository changes are not rolled back.
It checks for niri 26.04+ and validates desktop and greeter KDL before deploying
configuration. Packages or repository definitions may already have been changed
when a later validation fails.

Select the packaged **niri** session at login, or use `niri-session` from a TTY.
The session wrapper sets up systemd/D-Bus activation needed by desktop portals;
do not replace it with a bare `niri` command for the normal user desktop.

```sh
git clone https://github.com/d1dee/niri-dotfiles.git
cd niri-dotfiles
./setup
```

Run setup as your normal user; it requests sudo when needed. Internet access is
required for repositories, packages, missing fonts, and optional LibreTranslate.
Use `./setup --help` for usage or `./setup --skip-libretranslate` to omit the
translation environment.

Existing configuration files that would be overwritten are backed up under
`~/.local/share/bnsplit-backup/<timestamp>/`. These file backups do not undo
package transactions, COPR enablement, or systemd service/default-target changes.

The installer maps Fedora package names, downloads Material Symbols Sharp from
Google's upstream repository when missing, rewrites the original home path, and
checks the bundled x86_64 utilities for missing shared libraries. Unmanaged
utilities and Outfit fonts are installed under `/usr/local`, with SELinux labels
restored. No SELinux policy is disabled or relaxed.

**The installer now sets up the Quickshell greeter and lock screen.** It installs
Fedora's `greetd`, `greetd-selinux`, and D-Bus packages, enables `greetd.service`,
and selects `graphical.target` for the next boot. An existing display manager is
disabled for future boots, but no active display manager is stopped or restarted.
Reboot when ready and select niri at the new login screen.

### Greeter And Lock

The greeter runs as Fedora's packaged `greetd` system account. Its launcher is
`/usr/local/bin/bnsplit-greeter` and its QML/config/assets are a root-owned copy
under `/usr/local/share/bnsplit-greeter`. Personal preferences, API keys, and
private wallpaper paths are not copied into the greeter's settings/data files.
The bundled wallpaper and palette are used instead. Only last-user/session and
greeter preferences are writable under `/var/lib/greetd/bnsplit`; cache and
configuration directories also live under `/var/lib/greetd`. No home-directory
ACLs or access to your private configuration are needed. Re-run `setup` after
changing greeter code to refresh the system copy. It uses its own minimal niri
configuration and private D-Bus session, without launching desktop autostarts.

Login uses Fedora's packaged greetd PAM stacks unchanged. The Quickshell lock
screen uses the separate `/etc/pam.d/bnsplit-lock` service, which includes
`system-auth` and respects your authselect authentication settings. It uses the
Wayland session-lock protocol and only releases the lock after PAM reports
success. IPC/logind unlock notifications are not treated as authentication.
`Super + Delete` or `loginctl lock-session` requests a lock through the niri lock
helper and swayidle. Idle locking starts after 10 minutes; swaylock is the
fallback if Quickshell cannot acquire the session lock. The helper checks actual
lock acquisition instead of treating a successful IPC request as proof of a lock.

Keep a spare TTY/root-capable shell available for the first test. Verify a
rejected password, a successful password, login/logout, locking on every monitor,
and suspend/resume before relying on unattended locking. Actual authentication
and hardware/session behavior require a real Fedora session test. The installer
does not lock, log out, or reboot the current session automatically.

For greeter startup failures, switch to a TTY with `Ctrl + Alt + F3` and inspect:

```sh
journalctl -b -u greetd.service
sudo ausearch -m AVC,USER_AVC -ts recent
```

Keep SELinux enforcing. The installer uses Fedora's greetd policy and restores
standard file contexts; investigate any AVC denials rather than disabling policy
or granting broad home access. To recover to text login on the next boot:

```sh
sudo systemctl disable greetd.service
sudo systemctl set-default multi-user.target
```

Alternatively, disable greetd and re-enable your previous display manager.

LibreTranslate is installed into a Python virtual environment. If its Python or
binary dependencies are unavailable on your Fedora release, use
`./setup --skip-libretranslate`; the translation feature will then require a
separate working LibreTranslate environment.

### Optional Features

Optional packages are installed only when available in enabled repositories;
missing packages produce warnings instead of aborting the install. These include
Ghostty/WezTerm, GPU Screen Recorder, MoreWaita, Bibata cursors, Upscayl, and the
Pillow JPEG XL plugin. Install missing themes/tools separately if you use those
features. The standard JetBrains Mono package is not a Nerd Font; install a
patched font separately if desired. Set `UPSCAYL_MODELS_DIR` if your Upscayl
models are not in `/usr/share/upscayl/models`.

The default browser is Firefox. Review monitor, keyboard, hardware, and personal
application settings in `files/home/.config/niri/` before installation. Fedora's
`ffmpeg-free` is used; additional codecs may require separately configured
repositories. Bundled `bnclip`/`bnchroma` binaries may need rebuilding if their
glibc requirements differ from your Fedora release. Full desktop login,
screen-lock authentication, and optional integrations still need a real-session
smoke test on the target machine.

### Keybinds

- `Super + K` niri's native hotkey overlay
- `Super + Enter` terminal
- `Super + Space` launcher
- `Super + Delete` lock screen
- `Super + Tab` niri overview
- `Alt + Tab` shell icon/title switcher (Enter or click also activates)
- `Super + Shift + S` native screenshot selection
- `Super + Control + Shift + S` OCR selection, copied as text
- `Super + Alt + Shift + S` Google Lens selection (uploads selected image)
- `Super + H/L` workspace up/down
- `Super + Alt + H/J/K/L` focus columns/windows
- `Super + Control + H/J/K/L` move columns/windows
- `Super + 1..9` workspace index on the focused output
- `Super + Shift + 1..9` move window to a workspace
- `Super + Control + Shift + E` log out, with niri confirmation

The native configuration is `~/.config/niri/config.kdl`; it includes separate
output and appearance fragments. Native dynamic workspaces and scrolling columns
replace the previous compositor's dwindle/special-workspace behavior.

### Migration Differences

The shell consumes niri's JSON event stream and opaque window/workspace IDs.
Alt-Tab retains app icons and titles, but not Hyprland-only toplevel-export
thumbnails; use niri's overview for live window previews. The bar keeps its normal
layout because niri IPC does not expose equivalent fullscreen/maximized state.
Output mirroring, pinned/sticky windows, overlay scratchpads, and cursor zoom are
not emulated. Compositor-wide blur is unavailable; the shell's own lock-screen
blur remains. Edit native niri rules and bindings for column/floating behavior.

Screen sharing uses `xdg-desktop-portal-gnome` with the standard portal chooser,
not the old custom XDPH picker. GTK handles file choosers; X11 applications use
`xwayland-satellite`. The wallpaper portal uses D-Bus activation to call the
existing wallpaper setter. Do not export `GDK_BACKEND` globally, as this breaks the
GNOME screencast portal. Night light uses wlsunset and depends on GPU gamma
support. Capture/recording and mixed-DPI behavior still require hardware testing.

Region capture, OCR, and Lens use niri's native selection UI rather than a
full-screen shell preview, so canceled or small selections do not silently add a
full-screen image to clipboard history. Screen recording requires a recent GPU
Screen Recorder with portal and first-frame timestamp support; its GNOME consent
dialog chooses the screen/window. Arbitrary recording rectangles are not
supported; use OBS with a crop filter for that workflow.

Confirmed selections are copied by niri and can enter clipboard history. Escape
cancellation is not reported by niri IPC, so a shell-initiated OCR/Lens capture
can remain pending until its 120-second deadline. Native screenshot shortcuts
do not depend on that helper deadline.

Existing installed compositor packages/configurations are not uninstalled or
deleted automatically. The source deployment and capture list now target niri.

## Repository Layout

- `setup`: Fedora package/repository setup, staged deployment, backups, and greetd enablement
- `files/home/`: user configuration and scripts, including niri and Quickshell
- `files/root/`: system files staged for deployment, including greetd, PAM, portal metadata, and bundled utilities/fonts
- `includes.txt` / `excludes.txt`: paths and filters used by `store`
- `store`: rebuilds `files/` from the current machine and regenerates the bundled greeter palette; it replaces the existing snapshot, so do not run it just to install
- `tests/`: sandboxed installer, backend, settings, capture, and authentication-handler regression tests

## Validation

With Bash, rsync, Node.js, Python 3, and niri available:

```sh
bash -n setup
bash tests/test-fedora-setup.sh
node --test tests/*.mjs
python3 tests/test-niri-settings.py
python3 tests/test-niri-capture.py
```

The installer tests mock privileged operations, package transactions, COPR
enablement, and deployment. Other tests use mocked IPC and offline niri
validation; they do not replace a real-session test of login, lock, portals,
recording, or suspend/resume. Full QML linting has not been performed.

## Software overview

| Software                              | Purpose                                                                            |
| ------------------------------------- | ---------------------------------------------------------------------------------- |
| [niri](https://github.com/niri-wm/niri) | Scrollable-tiling Wayland compositor for desktop and greeter |
| [Quickshell](https://quickshell.org/) | QtQuick desktop shell: bar, launcher, OSD, notifications, lock screen, and greeter |
| Others                                | See [`setup`](setup) for the full package list                                     |
