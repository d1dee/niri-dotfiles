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

**Your existing display manager is preserved.** Log out and select Hyprland at
the login screen after installation. The upstream Quickshell greetd system
configuration is deliberately not deployed: it executes user-writable code from
a private home directory and has not been validated with Fedora's SELinux/PAM
policy. The regular desktop shell and lock screen remain included.

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

The keybind list only shows documented keyboard binds. Mouse binds, submaps, and undocumented binds are not listed.

## Software overview

| Software                              | Purpose                                                                            |
| ------------------------------------- | ---------------------------------------------------------------------------------- |
| [Hyprland](https://hyprland.org/)     | Wayland compositor                                                                 |
| [Quickshell](https://quickshell.org/) | QtQuick desktop shell: bar, launcher, OSD, notifications, lock screen, and greeter |
| Others                                | See [`setup`](setup) for the full package list                                     |
