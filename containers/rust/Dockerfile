# Rust agent container: gh + git + Rust toolchain + Claude Code.
# Built and run with Apple's `container` CLI on a Mac mini (arm64).
FROM debian:bookworm-slim

ARG CLAUDE_CHANNEL=latest
ARG AGENT_UID=1000
ARG AGENT_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Base tooling.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg \
        git openssh-client \
        build-essential pkg-config libssl-dev cmake \
        tmux less jq vim-tiny procps sudo util-linux \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI and Claude Code from their signed apt repos.
RUN install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
         -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
         > /etc/apt/sources.list.d/github-cli.list \
    && curl -fsSL https://downloads.claude.ai/keys/claude-code.asc \
         -o /etc/apt/keyrings/claude-code.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/${CLAUDE_CHANNEL} ${CLAUDE_CHANNEL} main" \
         > /etc/apt/sources.list.d/claude-code.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh claude-code \
    && rm -rf /var/lib/apt/lists/*

# Rust toolchain, installed system-wide so it survives the home volume mount.
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path \
        --default-toolchain stable --profile default --component rust-analyzer \
    && rustup --version && cargo --version && rustc --version

# Unprivileged user. /home/agent is a persistent volume mounted at runtime.
RUN groupadd -g "${AGENT_GID}" agent \
    && useradd -m -u "${AGENT_UID}" -g "${AGENT_GID}" -s /bin/bash agent \
    && echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent \
    && chmod 0440 /etc/sudoers.d/agent \
    && chown -R agent:agent /usr/local/rustup /usr/local/cargo \
    && git config --system credential.helper '!gh auth git-credential'

COPY entrypoint.sh /usr/local/bin/entrypoint
COPY claude-remote.sh /usr/local/bin/claude-remote
RUN chmod +x /usr/local/bin/entrypoint /usr/local/bin/claude-remote

# Per-user cargo cache lives in the persistent home so crate downloads survive.
ENV HOME=/home/agent \
    USER=agent \
    CARGO_HOME=/home/agent/.cargo \
    PATH=/home/agent/.cargo/bin:/home/agent/.local/bin:/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /home/agent/work
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["claude"]
