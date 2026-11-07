#!/bin/bash
# Usage: claude-remote [count] [name] [claude args...]
# Starts `claude --remote-control` (count sessions, default 1) inside a tmux session and keeps the
# container alive while that session runs. Attach from the host with:
#   ./agent rust attach
set -euo pipefail

SESSION=claude
GRACE_AFTER_EXIT="${AGENT_REMOTE_GRACE_SECONDS:-600}"

# Optional leading integer = number of parallel sessions (default 1).
COUNT=1
if [ "$#" -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
    COUNT=$1
    shift
    if [ "$COUNT" -lt 1 ]; then
        echo "error: session count must be >= 1" >&2
        exit 1
    fi
fi

# Remaining args: optional session name, then extra claude flags.
name=""
if [ "$#" -gt 0 ]; then
    name=$1
    shift
fi

# One tmux window per session. With a name and COUNT > 1, sessions are
# named "<name> 1", "<name> 2", ...; without one, claude auto-names each.
for i in $(seq 1 "$COUNT"); do
    cmd=(claude --remote-control)
    if [ -n "$name" ]; then
        if [ "$COUNT" -gt 1 ]; then cmd+=("$name $i"); else cmd+=("$name"); fi
    fi
    cmd+=("$@")

    # Quote each arg so session names with spaces survive tmux's shell.
    cmd_str=$(printf '%q ' "${cmd[@]}")

    if [ "$i" -eq 1 ]; then
        tmux new-session -d -s "$SESSION" -x 200 -y 50 "$cmd_str"
        # Keep panes after claude exits so failures (e.g. not logged in) are readable.
        tmux set-option -t "$SESSION" remain-on-exit on
    else
        tmux new-window -t "$SESSION:" "$cmd_str"
    fi
    echo "Running: ${cmd[*]}"
done

echo "tmux session '$SESSION' started with $COUNT window(s). Attach with: ./agent rust attach"
echo "Switch windows inside tmux with Ctrl-b n / Ctrl-b p."

# Stay alive while claude runs. Once it exits, wait a grace period for
# someone to attach and read the output, then let the container stop.
dead_since=""
while tmux has-session -t "$SESSION" 2>/dev/null; do
    if [ "$(tmux list-panes -s -t "$SESSION" -F '#{pane_dead}' | grep -c '^0$' || true)" = "0" ]; then
        now=$(date +%s)
        dead_since="${dead_since:-$now}"
        if [ $(( now - dead_since )) -ge "$GRACE_AFTER_EXIT" ]; then
            echo "all claude sessions exited ${GRACE_AFTER_EXIT}s ago; shutting down."
            tmux kill-session -t "$SESSION" 2>/dev/null || true
            break
        fi
    fi
    sleep 5
done
