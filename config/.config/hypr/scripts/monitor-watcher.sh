#!/usr/bin/env bash
# Listen on Hyprland's socket2 for monitor hotplug events and run the
# reconcile script. Designed to:
#   - auto-reconnect if socat dies or Hyprland restarts
#   - filter on the v2 events only (each hotplug emits both v1 and v2;
#     v2 carries id,name,description so we get one signal per change)
#   - debounce bursts so multiple events coalesce into a single switch
#   - log to the same file as the switch script

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWITCH="$SCRIPT_DIR/monitor-switch.sh"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hypr"
LOG_FILE="$LOG_DIR/monitor.log"
DEBOUNCE_SECONDS=1

mkdir -p "$LOG_DIR"

log() {
    printf '%s [watcher] %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

socket_path() {
    local runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        printf '%s/hypr/%s/.socket2.sock' "$runtime" "$HYPRLAND_INSTANCE_SIGNATURE"
        return
    fi
    # Fallback for systemd-user start where env wasn't imported: pick the
    # newest hypr instance socket. There is at most one active session per
    # user in practice.
    local newest
    newest=$(ls -1t "$runtime"/hypr/*/.socket2.sock 2>/dev/null | head -1)
    printf '%s' "$newest"
}

# Debounced switch invocation. If a previous switch is still pending,
# the new event extends the wait so a burst of monitor* events triggers
# exactly one reconcile after the burst settles.
PENDING_PID=""
schedule_switch() {
    if [[ -n "$PENDING_PID" ]] && kill -0 "$PENDING_PID" 2>/dev/null; then
        kill "$PENDING_PID" 2>/dev/null
    fi
    (
        sleep "$DEBOUNCE_SECONDS"
        log "running switch"
        if "$SWITCH"; then
            sleep 0.8
            pkill -x waybar 2>/dev/null || true
            waybar </dev/null >/dev/null 2>&1 &
            disown
            log "waybar restarted"
        else
            log "switch exited non-zero ($?)"
        fi
    ) &
    PENDING_PID=$!
}

log "starting; socket=$(socket_path) switch=$SWITCH"

backoff=1
while true; do
    sock=$(socket_path)
    if [[ ! -S "$sock" ]]; then
        log "socket missing ($sock); waiting"
        sleep "$backoff"
        backoff=$(( backoff < 16 ? backoff * 2 : 16 ))
        continue
    fi
    backoff=1

    # -U: unidirectional; we only read events, never write.
    socat -U - "UNIX-CONNECT:$sock" 2>>"$LOG_FILE" | while IFS= read -r line; do
        case "$line" in
            # Skip Hyprland's internal FALLBACK monitor swap that fires
            # during reload / when no real monitors are present. It's not
            # a real hotplug and triggering on it causes a reload storm.
            monitoraddedv2\>\>*,FALLBACK,*|monitorremovedv2\>\>*,FALLBACK,*)
                log "ignored fallback event: $line"
                ;;
            monitoraddedv2\>\>*|monitorremovedv2\>\>*)
                log "event: $line"
                schedule_switch
                ;;
        esac
    done

    log "socat exited; reconnecting in ${backoff}s"
    sleep "$backoff"
    backoff=$(( backoff < 16 ? backoff * 2 : 16 ))
done
