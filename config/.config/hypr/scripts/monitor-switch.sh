#!/usr/bin/env bash
# Reconcile monitor state.
#
# Desired state:
#   HDMI-A-1 present  -> eDP-1 disabled
#   HDMI-A-1 absent   -> eDP-1 enabled
#
# Hyprland 0.55 quirk (preserved from earlier work):
#   `hyprctl keyword monitor ...` is rejected under the non-legacy (lua)
#   parser ("keyword can't work with non-legacy parsers. Use eval."), so
#   disable is driven via `hyprctl eval` with a Lua expression. Lifting
#   the disabled flag via the same `hl.monitor(... disabled=false)` call
#   does NOT actually re-enable the output, so the only reliable path
#   back is `hyprctl reload`, which re-evaluates hyprland.lua where
#   eDP-1 is declared enabled.

set -u

EXTERNAL="HDMI-A-1"
INTERNAL="eDP-1"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hypr"
LOG_FILE="$LOG_DIR/monitor.log"
LOCK_FILE="$LOG_DIR/monitor-switch.lock"
MAX_ATTEMPTS=6
SETTLE_MS=500

mkdir -p "$LOG_DIR"

log() {
    printf '%s [switch] %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

# Serialize concurrent invocations from the watcher and from autostart.
exec 9>"$LOCK_FILE"
if ! flock -w 5 9; then
    log "could not acquire lock; another switch in flight, exiting"
    exit 0
fi

# Returns 0 if monitor is currently connected (present in `monitors all`).
external_present() {
    hyprctl monitors all -j 2>/dev/null \
        | jq -e --arg n "$EXTERNAL" 'any(.[]; .name == $n)' >/dev/null
}

# Returns 0 if internal is disabled, 1 if enabled, 2 if not present at all.
# Note: jq's `//` treats `false` the same as `null`, so we cannot use it
# to distinguish "disabled is false" from "monitor missing". Emit nothing
# when the monitor isn't in the list and key on the empty string instead.
internal_state() {
    local state
    state=$(hyprctl monitors all -j 2>/dev/null \
        | jq -r --arg n "$INTERNAL" '.[] | select(.name == $n) | .disabled')
    case "$state" in
        true)  return 0 ;;
        false) return 1 ;;
        "")    return 2 ;;
        *)     return 2 ;;
    esac
}

disable_internal() {
    hyprctl eval "hl.monitor({output = \"$INTERNAL\", disabled = true})" >/dev/null
}

enable_internal() {
    # Reload re-evaluates hyprland.lua, which restores eDP-1 enabled.
    hyprctl reload >/dev/null
}

reconcile() {
    local want_disabled attempt
    if external_present; then
        want_disabled=1
    else
        want_disabled=0
    fi

    local did_reload=0
    for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
        internal_state
        local cur=$?

        if [[ $cur -eq 2 ]]; then
            # Transient: monitor list still settling (e.g. mid-reload, fallback
            # swap). Wait and re-poll instead of bailing.
            log "attempt $attempt: $INTERNAL not in monitor list yet, waiting"
            sleep "0.$(printf '%03d' "$SETTLE_MS")"
            continue
        fi

        if [[ $want_disabled -eq 1 && $cur -eq 0 ]]; then
            log "converged: external present, internal disabled"
            return 0
        fi
        if [[ $want_disabled -eq 0 && $cur -eq 1 ]]; then
            log "converged: external absent, internal enabled"
            return 0
        fi

        if [[ $want_disabled -eq 1 ]]; then
            log "attempt $attempt: external=$EXTERNAL present, disabling $INTERNAL"
            disable_internal
        else
            # Reload is the only known way in 0.55 to lift the disabled flag
            # (lua hl.monitor with disabled=false is a no-op — the field
            # handler in LuaBindingsConfigRules.cpp only acts when true).
            # Reload is heavy and triggers a FALLBACK monitor swap; do it
            # only once per invocation.
            if [[ $did_reload -eq 1 ]]; then
                log "attempt $attempt: already reloaded, waiting for state to settle"
                sleep "0.$(printf '%03d' "$SETTLE_MS")"
                continue
            fi
            log "attempt $attempt: external=$EXTERNAL absent, enabling $INTERNAL via reload"
            enable_internal
            did_reload=1
        fi

        sleep "0.$(printf '%03d' "$SETTLE_MS")"
    done

    log "WARN: failed to converge after $MAX_ATTEMPTS attempts (want_disabled=$want_disabled)"
    return 1
}

reconcile
