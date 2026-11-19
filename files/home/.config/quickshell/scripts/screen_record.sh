#!/usr/bin/env bash
set -uo pipefail
umask 077

RECORD_DIR="$HOME/Videos/Record"
runtime="${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/bnsplit-recording"
mkdir -p -- "$runtime"
notify_enabled=false
shell_enabled=false
audio=default_output
command=${1:-help}
shift || true
for arg in "$@"; do
  case "$arg" in
    notif) notify_enabled=true ;;
    quickshell) shell_enabled=true ;;
    mic) audio='default_output|default_input' ;;
    *)
      printf '%s\n' 'Explicit monitor/region recording is unsupported through the portal. Use start without a target, select a screen/window in the GNOME chooser, or use OBS with a crop filter.' >&2
      notify-send 'Recording unsupported' 'Use the portal screen/window chooser; region capture requires OBS with a crop filter.'
      exit 2 ;;
  esac
done

notify() {
  printf '%s: %s\n' "$1" "$2"
  if "$notify_enabled"; then
    notify-send --app-name='Screen Recording' --icon=replay-record "$1" "$2"
  fi
}

update_shell() {
  if "$shell_enabled"; then
    qs ipc call data set isRecording "$1" >/dev/null 2>&1 || true
    if [[ "$1" == false ]]; then
      qs ipc call data set recordingRegion null >/dev/null 2>&1 || true
    fi
  fi
}

# Compare Linux process start times as well as PIDs, so stale state cannot signal a reused PID.
start_time() {
  local stat fields
  IFS= read -r stat 2>/dev/null < "/proc/$1/stat" || return 1
  read -ra fields <<< "${stat##*) }"
  printf '%s' "${fields[19]}"
}

is_running() {
  local saved
  [[ -r "$runtime/process" ]] || return 1
  read -r recorder saved < "$runtime/process" || return 1
  [[ "$recorder" =~ ^[0-9]+$ && -n "$saved" && "$(start_time "$recorder")" == "$saved" ]]
}

latest() {
  local file newest=''
  shopt -s nullglob
  for file in "$RECORD_DIR"/*.mkv; do
    [[ -z "$newest" || "$file" -nt "$newest" ]] && newest="$file"
  done
  printf '%s' "$newest"
}

start_recording() {
  exec 9>"$runtime/lock"
  flock -n 9 || { notify 'Recording busy' 'A recording or portal selection is already pending.'; return 1; }
  local help
  help=$(gpu-screen-recorder --help 2>&1) || true
  if [[ "$help" != *portal* || "$help" != *-write-first-frame-ts* ]]; then
    notify 'Recording unavailable' 'Install a gpu-screen-recorder version supporting -w portal and -write-first-frame-ts, plus PipeWire and xdg-desktop-portal-gnome. OBS PipeWire capture is an alternative.'
    return 2
  fi
  mkdir -p -- "$RECORD_DIR"
  local filepath="$RECORD_DIR/Video_$(date +%Y-%m-%d_%H-%M-%S_%N).mkv"
  local recorder='' started=false status=0
  rm -f -- "$runtime/active" "$runtime/stop-requested"
  update_shell false
  gpu-screen-recorder -w portal -restore-portal-session no -write-first-frame-ts yes -q ultra -k h264 -ac aac -f 60 -c mkv -a "$audio" -o "$filepath" >"$runtime/recorder.log" 2>&1 9>&- &
  recorder=$!
  printf '%s %s\n' "$recorder" "$(start_time "$recorder")" > "$runtime/process"
  trap 'kill -INT "$recorder" 2>/dev/null || true' TERM INT
  while kill -0 "$recorder" 2>/dev/null; do
    # This marker is written only after the first captured frame, not while consent is pending.
    if ! "$started" && [[ -s "$filepath.ts" ]]; then
      started=true
      : > "$runtime/active"
      update_shell true
      notify 'Recording started' "Saving portal selection to $filepath"
    fi
    sleep 0.2
  done
  wait "$recorder" || status=$?
  [[ -s "$filepath.ts" ]] && started=true
  local stopped=false
  [[ -e "$runtime/stop-requested" ]] && stopped=true
  trap - TERM INT
  update_shell false
  rm -f -- "$runtime/process" "$runtime/active" "$filepath.ts"
  flock -u 9
  if "$started" && [[ "$status" == 0 ]]; then
    notify 'Recording saved' "$filepath"
  elif "$stopped" && ! "$started"; then
    notify 'Recording cancelled' 'Portal selection was stopped before capture began.'
  else
    notify 'Recording ended without success' "Portal consent was cancelled or capture/encoding failed. Check $runtime/recorder.log; verify GNOME portal, PipeWire, and hardware encoder support."
    [[ "$status" == 0 ]] && status=1
  fi
  return "$status"
}

stop_recording() {
  is_running || { update_shell false; notify 'Not recording' 'No managed recording is active.'; return 1; }
  : > "$runtime/stop-requested"
  kill -INT "$recorder"
}

case "$command" in
  start) start_recording ;;
  stop) stop_recording ;;
  toggle) if is_running; then stop_recording; else start_recording; fi ;;
  status|notif)
    [[ "$command" == notif ]] && notify_enabled=true
    if is_running; then
      if [[ -e "$runtime/active" ]]; then notify 'Recording active' "$RECORD_DIR"; else notify 'Recording pending' 'Waiting for portal consent or first frame.'; fi
    else
      update_shell false
      notify 'Not recording' "$RECORD_DIR"
    fi ;;
  open) file=$(latest); xdg-open "${file:-$RECORD_DIR}" ;;
  folder) xdg-open "$RECORD_DIR" ;;
  *) printf '%s\n' 'Usage: screen_record.sh {start|stop|toggle|status|notif|open|folder} [quickshell] [notif] [mic]' 'Screen/window selection is provided by the GNOME PipeWire portal. Explicit monitor and region targets are unsupported.'; exit 2 ;;
esac
