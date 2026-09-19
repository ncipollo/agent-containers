#!/bin/bash
# Runs as root: prepares the persistent home volume, then drops to `agent`.
set -euo pipefail

HOME_DIR=/home/agent

# First boot on a fresh volume: seed the skeleton and workspace.
if [ ! -f "$HOME_DIR/.agent-seeded" ]; then
    cp -rn /etc/skel/. "$HOME_DIR"/ 2>/dev/null || true
    mkdir -p "$HOME_DIR/work" "$HOME_DIR/.claude" "$HOME_DIR/.config" "$HOME_DIR/.cargo"
    touch "$HOME_DIR/.agent-seeded"
    chown -R agent:agent "$HOME_DIR"
fi

# Cheap ownership check on later boots; a full recursive chown would be slow
# once cargo caches accumulate.
if [ "$(stat -c %u "$HOME_DIR")" != "$(id -u agent)" ]; then
    chown -R agent:agent "$HOME_DIR"
fi

if [ "$#" -eq 0 ]; then
    set -- claude
fi

exec setpriv --reuid=agent --regid=agent --init-groups \
    env HOME="$HOME_DIR" USER=agent LOGNAME=agent "$@"
