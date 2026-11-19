<div align="center">
    <h1>BnSplit's dotfiles</h1>
</div>

https://github.com/user-attachments/assets/f3fd43bb-1a19-442a-9920-9c2a3e5ce66b

## Screenshots

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
- Launcher pages: apps, files, clipboard (via [bnclip](https://github.com/bnsplits/bnclip)), emojis, calculator, keybinds, monitors, processes, tasks, translate, commands, web search, and wallpaper pickers (local, Wallhaven, Unsplash)
- Wallpaper-driven theming via [bnchroma](https://github.com/bnsplits/bnchroma) + [awww](https://codeberg.org/LGFae/awww/pulls/571/files)
- Lean GNOME integration: calendars events via Evolution Data Server, Control Center additional settings, Nautilus's Set as Background...

## Installation

This port targets **mutable Fedora with DNF5 on x86_64** (not Silverblue, Kinoite,
or other rpm-ostree desktops). It replaces the Arch package installer, update
widget, and package pickers with Fedora/DNF5 equivalents.

The Lua configuration requires **Hyprland 0.55 or newer** with `start-hyprland`.
Configure a repository providing the current Hyprland stack before running
`setup`. For example, the third-party
[nett00n/hyprland COPR](https://copr.fedorainfracloud.org/coprs/nett00n/hyprland/)
provides recent Hyprland and Quickshell builds. COPR packages are community
maintained, not supported by Fedora; review the repository before enabling it:

```sh
sudo dnf5 copr enable nett00n/hyprland
```

You also need an RPM providing `awww` and `awww-daemon`. If your enabled
repositories do not provide it, review an awww repository such as
[mineiro/hyprland](https://copr.fedorainfracloud.org/coprs/mineiro/hyprland/).
Avoid mixing incompatible Hyprland stacks from multiple COPRs. `setup` never
enables third-party repositories automatically and stops before deploying any
configuration if a required package or session executable is missing.

```sh
git clone https://github.com/bnsplits/dotfiles.git
cd dotfiles
./setup
```

Existing files that would be overwritten are backed up first.

The installer maps Fedora package names, downloads Material Symbols Sharp from
Google's upstream repository when missing, rewrites the original home path, and
checks the bundled x86_64 utilities for missing shared libraries. Unmanaged
utilities and Outfit fonts are installed under `/usr/local`, with SELinux labels
restored. No SELinux policy is disabled or relaxed.

**The installer now sets up the Quickshell greeter and lock screen.** It installs
Fedora's `greetd`, `greetd-selinux`, and D-Bus packages, enables `greetd.service`,
and selects `graphical.target` for the next boot. An existing display manager is
disabled for future boots, but no active display manager is stopped or restarted.
Reboot when ready and select Hyprland at the new login screen.

### Greeter And Lock

The greeter runs as Fedora's packaged `greetd` system account. Its launcher is
`/usr/local/bin/bnsplit-greeter` and its QML/config/assets are a root-owned copy
under `/usr/local/share/bnsplit-greeter`. Personal preferences, API keys, and
private wallpaper paths are not copied into the greeter's settings/data files.
The bundled wallpaper and palette are used instead. Only last-user/session and
greeter preferences are writable under `/var/lib/greetd/bnsplit`; cache and
configuration directories also live under `/var/lib/greetd`. No home-directory
ACLs or access to your private configuration are needed. Re-run `setup` after
changing greeter code to refresh the system copy.

Login uses Fedora's packaged greetd PAM stacks unchanged. The Quickshell lock
screen uses the separate `/etc/pam.d/bnsplit-lock` service, which includes
`system-auth` and respects your authselect authentication settings. It uses the
Wayland session-lock protocol and only releases the lock after PAM reports
success. IPC/logind unlock notifications are not treated as authentication.
`Super + Delete` or `loginctl lock-session` requests a lock through hypridle;
idle locking starts after 10 minutes. If Quickshell IPC is unavailable, hypridle
falls back to hyprlock.

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

Alternatively, disable greetd and re-enable your previous display manager. The
normal file backup does not restore systemd enablement/default-target changes.

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
application settings in `files/home/.config/hypr/` before installation. Fedora's
`ffmpeg-free` is used; additional codecs may require separately configured
repositories. Bundled `bnclip`/`bnchroma` binaries may need rebuilding if their
glibc requirements differ from your Fedora release. Full desktop login,
screen-lock authentication, and optional integrations still need a real-session
smoke test on the target machine.

### Keybinds

- `Super + K` keybind list
- `Super + Enter` terminal
- `Super + Delete` lock screen

The keybind list only shows documented keyboard binds. Mouse binds, submaps, and undocumented binds are not listed.

## Software overview

| Software                              | Purpose                                                                            |
| ------------------------------------- | ---------------------------------------------------------------------------------- |
| [Hyprland](https://hyprland.org/)     | Wayland compositor                                                                 |
| [Quickshell](https://quickshell.org/) | QtQuick desktop shell: bar, launcher, OSD, notifications, lock screen, and greeter |
| Others                                | See [`setup`](setup) for the full package list                                     |
