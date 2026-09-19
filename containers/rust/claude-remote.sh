#!/bin/bash
# Starts `claude --remote-control` inside a tmux session and keeps the
# container alive while that session runs. Attach from the host with:
#   ./agent rust attach
set -euo pipefail

SESSION=claude
GRACE_AFTER_EXIT="${AGENT_REMOTE_GRACE_SECONDS:-600}"

cmd=(claude --remote-control)
if [ "$#" -gt 0 ] && [ -n "$1" ]; then
    cmd+=("$1")
fi
if [ "$#" -gt 0 ]; then
    shift
fi
cmd+=("$@")

# Quote each arg so session names with spaces survive tmux's shell.
cmd_str=$(printf '%q ' "${cmd[@]}")

tmux new-session -d -s "$SESSION" -x 200 -y 50 "$cmd_str"
# Keep the pane after claude exits so failures (e.g. not logged in) are readable.
tmux set-option -t "$SESSION" remain-on-exit on

echo "Running: ${cmd[*]}"
echo "tmux session '$SESSION' started. Attach with: ./agent rust attach"

# Stay alive while claude runs. Once it exits, wait a grace period for
# someone to attach and read the output, then let the container stop.
dead_since=""
while tmux has-session -t "$SESSION" 2>/dev/null; do
    if [ "$(tmux list-panes -t "$SESSION" -F '#{pane_dead}' | head -n1)" = "1" ]; then
        now=$(date +%s)
        dead_since="${dead_since:-$now}"
        if [ $(( now - dead_since )) -ge "$GRACE_AFTER_EXIT" ]; then
            echo "claude exited ${GRACE_AFTER_EXIT}s ago; shutting down."
            tmux kill-session -t "$SESSION" 2>/dev/null || true
            break
        fi
    fi
    sleep 5
done
