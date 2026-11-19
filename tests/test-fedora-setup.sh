#!/usr/bin/env bash
# No privileged command is executed: sudo is a fail-closed function below.
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if ((EUID == 0)); then
  printf 'Run these tests as an unprivileged user.\n' >&2
  exit 1
fi
for tool in bash rsync mktemp cp mkdir rm diff grep chmod sh; do
  command -v "$tool" >/dev/null || { printf 'Missing test dependency: %s\n' "$tool" >&2; exit 1; }
done
sandbox=$(mktemp -d "$repo/tests/.fedora-setup.XXXXXXXX")
trap 'command rm -rf -- "$sandbox"' EXIT
passes=0
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { passes=$((passes + 1)); printf 'PASS: %s\n' "$*"; }
contains() { command grep -Fq -- "$2" "$1" || fail "$1 lacks $2"; }
equal() { [[ $1 == "$2" ]] || fail "expected [$2], got [$1]"; }

fixture() {
  case_dir=$sandbox/$1
  command mkdir -p "$case_dir/repo/files/home/.config/quickshell/"{store,greeter,assets} \
    "$case_dir/repo/files/root/etc/"{greetd,tmpfiles.d,pam.d} \
    "$case_dir/repo/files/home/.local/share/fonts/MaterialSymbols" \
    "$case_dir/home/.config/quickshell/store" "$case_dir/root/usr/local/bin" \
    "$case_dir/tmp" "$case_dir/bin"
  command cp -- "$repo/setup" "$case_dir/repo/setup"
  command cp -- "$repo/files/home/.config/quickshell/greeter/greeter.sh" \
    "$case_dir/repo/files/home/.config/quickshell/greeter/greeter.sh"
  command cp -- "$repo/files/root/etc/greetd/config.toml" "$case_dir/repo/files/root/etc/greetd/"
  command cp -- "$repo/files/root/etc/tmpfiles.d/bn-greetd.conf" "$case_dir/repo/files/root/etc/tmpfiles.d/"
  command cp -- "$repo/files/root/etc/pam.d/bnsplit-lock" "$case_dir/repo/files/root/etc/pam.d/"
  printf '{"apiKey":"PRIVATE-KEY","wallpaper":"/home/bnsplit/private.png"}\n' > "$case_dir/repo/files/home/.config/quickshell/store/settings.json"
  printf '{"history":"PRIVATE-HISTORY"}\n' > "$case_dir/repo/files/home/.config/quickshell/store/data.json"
  printf '{"accent":"retained-theme"}\n' > "$case_dir/repo/files/home/.config/quickshell/store/theme.json"
  printf 'retained-asset\n' > "$case_dir/repo/files/home/.config/quickshell/assets/wallpaper.svg"
  printf 'font\n' > "$case_dir/repo/files/home/.local/share/fonts/MaterialSymbols/MaterialSymbolsSharp.ttf"
  printf 'font-license\n' > "$case_dir/repo/files/home/.local/share/fonts/MaterialSymbols/LICENSE"
  printf 'previous-home-settings\n' > "$case_dir/home/.config/quickshell/store/settings.json"
  printf 'previous-root-binary\n' > "$case_dir/root/usr/local/bin/bnclip"
  local prefix=usr
  [[ $2 == old ]] || prefix=usr/local
  command mkdir -p "$case_dir/repo/files/root/$prefix/bin" "$case_dir/repo/files/root/$prefix/share/fonts/Outfit"
  printf 'fake-bnclip\n' > "$case_dir/repo/files/root/$prefix/bin/bnclip"
  printf 'fake-bnchroma\n' > "$case_dir/repo/files/root/$prefix/bin/bnchroma"
  printf 'outfit-font\n' > "$case_dir/repo/files/root/$prefix/share/fonts/Outfit/Outfit.ttf"
  command cp -a -- "$case_dir/repo/files" "$case_dir/source-before"
  # Only these native programs are visible to setup. Privileged/runtime tools
  # have no executable fallback, even if a mock is accidentally removed.
  local tool
  for tool in dirname date cp mkdir mv chmod install grep sed xargs rm find wc rmdir rsync; do
    command ln -s -- "$(command -v "$tool")" "$case_dir/bin/$tool"
  done
  : > "$case_dir/actions"
}

run_setup() (
  export HOME=$case_dir/home TMPDIR=$case_dir/tmp
  export PATH=$case_dir/bin LC_ALL=C TERM=
  local_root=$case_dir/root
  actions=$case_dir/actions
  missing=${1:-}
  shift
  deny() { printf 'UNSAFE MOCK CALL: %s\n' "$*" >&2; exit 97; }
  log() { printf '%q ' "$@" >> "$actions"; printf '\n' >> "$actions"; }
  safe_path() {
    [[ $1 == "$case_dir/"* && $1 != *'/../'* && $1 != */.. ]] || deny "path $1"
    # Fixtures contain no symlinks except the separate command bin directory.
    [[ $1 != "$case_dir/bin/"* ]] || deny "command directory mutation $1"
  }
  source() {
    [[ $# == 1 && $1 == /etc/os-release ]] || deny "source $*"
    ID=fedora VERSION_ID=test
  }
  uname() { [[ $* == -m ]] || deny "uname $*"; printf 'x86_64\n'; }
  id() { case "$*" in -u|-g) printf '1000\n';; *) deny "id $*";; esac; }
  mktemp() {
    [[ $* == -d ]] || deny "mktemp $*"
    command mkdir -- "$TMPDIR/stage"
    printf '%s\n' "$TMPDIR/stage"
  }
  dnf5() {
    [[ $# -gt 5 && $1 == -q && $2 == repoquery && $3 == --available && $4 == --queryformat && $5 == '%{name}\n' ]] || deny "dnf5 $*"
    shift 5
    local pkg
    for pkg; do [[ $pkg == "$missing" ]] || printf '%s\n' "$pkg"; done
  }
  rpm() { [[ $# == 2 && $1 == -q ]] || deny "rpm $*"; return 1; }
  getent() { [[ $* == 'passwd greetd' ]] || deny "getent $*"; log getent "$@"; printf 'greetd:x:999:999::/var/lib/greetd:/sbin/nologin\n'; }
  fc-match() { [[ $* == '-f %{family} Material Symbols Sharp' ]] || deny "fc-match $*"; printf 'Material Symbols Sharp'; }
  ldd() { [[ $# == 1 ]] || deny "ldd $*"; safe_path "$1"; printf 'all dependencies found\n'; }
  fc-cache() { [[ $* == -f ]] || deny "fc-cache $*"; log fc-cache "$@"; }
  start-hyprland() { deny 'real compositor'; }
  qs() { deny 'real quickshell'; }
  awww() { deny 'real wallpaper service'; }
  awww-daemon() { deny 'real wallpaper daemon'; }
  dbus-run-session() { deny 'real session bus'; }
  python3() { deny 'LibreTranslate was not skipped'; }
  curl() { deny 'unexpected network access'; }
  systemctl() {
    log systemctl "$@"
    case "$*" in
      'is-enabled --quiet display-manager.service') return 0;;
      'show --property=Id --value display-manager.service') printf 'sddm.service\n';;
      *) deny "unprivileged systemctl $*";;
    esac
  }
  rsync() {
    local arg source_path destination backup_path= args=("$@")
    ((${#args[@]} >= 3)) || deny 'short rsync'
    source_path=${args[${#args[@]}-2]}
    destination=${args[${#args[@]}-1]}
    safe_path "$source_path"; safe_path "$destination"
    for arg; do
      case "$arg" in
        --backup-dir=*) backup_path=${arg#*=}; safe_path "$backup_path";;
        --chown=*) deny 'unprivileged rsync chown';;
      esac
    done
    log rsync "$@"
    command rsync "$@"
  }
  sudo() {
    log sudo "$@"
    case "$*" in
      '-v'|'dnf5 makecache --refresh') return 0;;
      'dnf5 install '*)
        [[ $1 == dnf5 && $2 == install && $# -gt 20 ]] || deny "sudo $*"
        local pkg
        for pkg in "${@:3}"; do [[ $pkg =~ ^[a-zA-Z0-9][a-zA-Z0-9+.-]*$ ]] || deny "package $pkg"; done
        return 0;;
      'systemd-sysusers /usr/lib/sysusers.d/greetd.conf') return 0;;
      'rsync '*)
        [[ $# == 9 && $2 == -rltEOc && $3 == --no-perms && $4 == --chown=root:root && $5 == --backup && $6 == --backup-dir="$HOME/.local/share/bnsplit-backup/"*/root && $7 == -- && $8 == "$TMPDIR/stage/root/" && $9 == / ]] || deny "sudo $*"
        safe_path "${6#*=}"
        log deploy-root
        command rsync "$2" "$3" "$5" "$6" -- "$8" "$local_root/";;
      'chown -R root:root /usr/local/share/bnsplit-greeter'|'chmod -R u=rwX,go=rX /usr/local/share/bnsplit-greeter'|\
      'chown root:root /usr/local/bin/bnsplit-greeter /etc/pam.d/bnsplit-lock'|\
      'chmod 0755 /usr/local/bin/bnsplit-greeter'|'chmod 0644 /etc/pam.d/bnsplit-lock'|\
      'systemd-tmpfiles --create /etc/tmpfiles.d/bn-greetd.conf'|\
      'restorecon -RF /usr/local/bin/bnclip /usr/local/bin/bnchroma /usr/local/bin/bnsplit-greeter /usr/local/share/bnsplit-greeter /usr/local/share/fonts/Outfit /usr/local/share/fonts/MaterialSymbols /var/lib/greetd /etc/greetd /etc/tmpfiles.d/bn-greetd.conf /etc/pam.d/bnsplit-lock'|\
      'fc-cache -f /usr/local/share/fonts') return 0;;
      'chown -R -- 1000:1000 '*) [[ $# == 5 && $5 == "$HOME/.local/share/bnsplit-backup/"* ]] || deny "sudo $*"; safe_path "$5";;
      'systemctl disable sddm.service'|'systemctl enable --force greetd.service'|'systemctl set-default graphical.target')
        [[ -f $local_root/usr/local/share/bnsplit-greeter/store/settings.json && -f $local_root/etc/pam.d/bnsplit-lock ]] || deny 'activation before deployment'
        ;;
      *) deny "sudo $*";;
    esac
  }
  # Guard native filesystem writers too; all absolute operands must remain in
  # this case. No mock ever forwards a privileged destination to a real tool.
  for tool in cp mkdir mv chmod install rm find rmdir sed; do
    eval "$tool() { local arg; for arg; do case \"\$arg\" in /*) safe_path \"\$arg\";; esac; done; command $tool \"\$@\"; }"
  done
  builtin source "$case_dir/repo/setup" "$@"
)

run_expect() {
  local expected=$1 status=0
  shift
  # A function used in `if`/`||` suppresses errexit even inside sourced setup.
  # Capture status without changing the installer's set -e semantics.
  set +e
  run_setup "$@" > "$case_dir/output" 2>&1
  status=$?
  set -e
  if [[ $status != "$expected" ]]; then
    command cp -- "$case_dir/output" "$sandbox/last-failure"
    printf 'Setup output:\n' >&2
    while IFS= read -r line; do printf '%s\n' "$line" >&2; done < "$case_dir/output"
    fail "setup exit $status, expected $expected"
  fi
}

for argument in --help -h --invalid 'extra'; do
  fixture "cli-${argument//-/}" new
  case $argument in
    --help|-h) run_expect 0 '' "$argument"; contains "$case_dir/output" 'Usage:';;
    --invalid) run_expect 1 '' "$argument"; contains "$case_dir/output" 'Unknown option:';;
    extra) run_expect 1 '' --skip-libretranslate --invalid; contains "$case_dir/output" 'Usage:';;
  esac
  [[ ! -s $case_dir/actions ]] || fail 'CLI argument handling invoked external side effects'
done
pass 'help, unknown option and excess arguments exit before side effects'

fixture missing-package old
run_expect 1 quickshell --skip-libretranslate
contains "$case_dir/output" 'required packages unavailable: quickshell'
equal "$(command wc -l < "$case_dir/actions")" 2
contains "$case_dir/actions" 'sudo -v'
contains "$case_dir/actions" 'sudo dnf5 makecache --refresh'
[[ ! -d $case_dir/tmp/stage ]] || fail 'missing packages reached staging'
equal "$(< "$case_dir/root/usr/local/bin/bnclip")" previous-root-binary
pass 'missing required package exits before transaction, staging or deployment'

for probe in service root-rsync outside-write traversal; do
  fixture "guard-$probe" new
  case $probe in
    service) printf '%s\n' 'sudo systemctl stop display-manager.service' > "$case_dir/repo/setup";;
    root-rsync) printf '%s\n' 'sudo rsync -a -- "$HOME/" /' > "$case_dir/repo/setup";;
    outside-write) printf '%s\n' 'mkdir -p /var/lib/bnsplit-test-must-not-exist' > "$case_dir/repo/setup";;
    traversal) printf '%s\n' 'mkdir -p "$HOME/../../bnsplit-test-must-not-exist"' > "$case_dir/repo/setup";;
  esac
  run_expect 97 ''
  contains "$case_dir/output" 'UNSAFE MOCK CALL:'
done
pass 'guards reject service mutation, arbitrary privileged rsync and escaping write paths'

for layout in old new; do
  fixture "success-$layout" "$layout"
  run_expect 0 '' --skip-libretranslate
  deployed=$case_dir/root/usr/local/share/bnsplit-greeter
  equal "$(< "$deployed/store/settings.json")" '{}'
  equal "$(< "$deployed/store/data.json")" '{}'
  contains "$deployed/store/theme.json" retained-theme
  contains "$deployed/assets/wallpaper.svg" retained-asset
  contains "$case_dir/root/etc/greetd/config.toml" 'user = "greetd"'
  contains "$case_dir/root/etc/greetd/config.toml" 'command = "/usr/local/bin/bnsplit-greeter"'
  contains "$case_dir/root/etc/pam.d/bnsplit-lock" 'auth include system-auth'
  contains "$case_dir/root/etc/tmpfiles.d/bn-greetd.conf" '0700 greetd greetd'
  command cmp -- "$case_dir/root/usr/local/bin/bnsplit-greeter" "$repo/files/home/.config/quickshell/greeter/greeter.sh"
  equal "$(< "$case_dir/root/usr/local/bin/bnclip")" fake-bnclip
  equal "$(< "$case_dir/root/usr/local/bin/bnchroma")" fake-bnchroma
  equal "$(< "$case_dir/root/usr/local/share/fonts/Outfit/Outfit.ttf")" outfit-font
  equal "$(< "$case_dir/root/usr/local/share/fonts/MaterialSymbols/MaterialSymbolsSharp.ttf")" font
  [[ ! -e $case_dir/root/usr/bin/bnclip ]] || fail 'old RPM-owned binary path deployed'
  command diff -r -- "$case_dir/source-before" "$case_dir/repo/files"
  backups=("$case_dir/home/.local/share/bnsplit-backup/"*)
  equal "${#backups[@]}" 1
  equal "$(< "${backups[0]}/home/.config/quickshell/store/settings.json")" previous-home-settings
  equal "$(< "${backups[0]}/root/usr/local/bin/bnclip")" previous-root-binary
  contains "$case_dir/actions" 'sudo systemd-sysusers /usr/lib/sysusers.d/greetd.conf'
  contains "$case_dir/actions" 'getent passwd greetd'
  contains "$case_dir/actions" 'sudo chown -R root:root /usr/local/share/bnsplit-greeter'
  contains "$case_dir/actions" 'sudo chmod -R u=rwX\,go=rX /usr/local/share/bnsplit-greeter'
  contains "$case_dir/actions" 'sudo chmod 0644 /etc/pam.d/bnsplit-lock'
  contains "$case_dir/actions" 'sudo systemd-tmpfiles --create /etc/tmpfiles.d/bn-greetd.conf'
  contains "$case_dir/actions" 'sudo restorecon -RF'
  contains "$case_dir/actions" 'sudo systemctl disable sddm.service'
  contains "$case_dir/actions" 'sudo systemctl enable --force greetd.service'
  contains "$case_dir/actions" 'sudo systemctl set-default graphical.target'
  contains "$case_dir/output" 'All done'
  [[ ! -d $case_dir/tmp/stage ]] || fail 'staging was not cleaned up'
  pass "$layout layout: sanitized greeter/assets, Fedora account/PAM, ownership intent, labels, backups, post-deploy activation"
done

# The launcher deliberately resets PATH, so intercept exec in a Bash source
# harness rather than trusting a PATH shim that the launcher would discard.
# sh -n separately verifies that the production /bin/sh script is valid.
command sh -n "$repo/files/home/.config/quickshell/greeter/greeter.sh"
(
  export HOME=$sandbox/untrusted XDG_CONFIG_HOME=$sandbox/untrusted/config XDG_CACHE_HOME=$sandbox/untrusted/cache
  export PATH=$sandbox/untrusted/bin BNSPLIT_GREETER=0
  export XDG_SESSION_TYPE=x11 XDG_SESSION_DESKTOP=Other XDG_CURRENT_DESKTOP=Other
  export MOZ_ENABLE_WAYLAND=0 QT_QPA_PLATFORM=xcb SDL_VIDEODRIVER=x11
  exec() {
    printf '%s\n' "$@" > "$sandbox/wrapper-argv"
    printf '%s\n' "$PATH" "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$BNSPLIT_GREETER" \
      "$XDG_SESSION_TYPE" "$XDG_SESSION_DESKTOP" "$XDG_CURRENT_DESKTOP" \
      "$MOZ_ENABLE_WAYLAND" "$QT_QPA_PLATFORM" "$SDL_VIDEODRIVER" > "$sandbox/wrapper-env"
  }
  builtin source "$repo/files/home/.config/quickshell/greeter/greeter.sh"
)
mapfile -t argv < "$sandbox/wrapper-argv"
equal "${#argv[@]}" 6
equal "${argv[*]}" 'dbus-run-session -- start-hyprland -- --config /usr/local/share/bnsplit-greeter/greeter/hyprland.lua'
pass 'wrapper invokes private dbus-run-session with exact compositor argv'
mapfile -t environment < "$sandbox/wrapper-env"
equal "${environment[*]}" '/usr/local/bin:/usr/bin:/bin /var/lib/greetd /var/lib/greetd/.config /var/lib/greetd/.cache 1 wayland Hyprland Hyprland 1 wayland wayland'
pass 'wrapper replaces personal paths and exports greeter/Wayland environment'

printf '\n%d regression groups passed; no real sudo, package transaction, service mutation, deployment or lock executed.\n' "$passes"
