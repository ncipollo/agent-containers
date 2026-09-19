# agent-containers

Containers that run [Claude Code](https://code.claude.com) on a Mac mini using
Apple's [`container`](https://github.com/apple/container) CLI. Each container is
a small Linux VM with a persistent home volume, so logins, shell history, cargo
caches and your `work/` directory survive across runs.

## Containers

| Name   | Contents                                                        |
| ------ | --------------------------------------------------------------- |
| `rust` | Debian, `git`, `gh`, stable Rust toolchain (rustup, clippy, rustfmt, rust-analyzer), build deps (`build-essential`, `pkg-config`, `libssl-dev`, `cmake`), `tmux`, Claude Code |

## One-time setup on the Mac mini

1. Install `container` (macOS 26+) and start it:

   ```sh
   brew install container      # or the pkg from https://github.com/apple/container/releases
   container system start
   ```

2. Clone this repo and build the image:

   ```sh
   git clone <this repo> ~/src/agent-containers
   cd ~/src/agent-containers
   ./agent rust build
   ```

3. Launch once interactively and sign in. Both logins persist in the volume.

   ```sh
   ./agent rust claude
   ```

   Inside Claude run `/login` and pick the claude.ai option. It prints a URL:
   open it on any device, then paste the code back. Remote Control needs a
   claude.ai subscription login, not an API key or `claude setup-token`.

   Then, from a shell in the container (`./agent rust sh`), sign in to GitHub
   and set your git identity:

   ```sh
   gh auth login        # pick HTTPS + "Login with a web browser" (device code)
   git config --global user.name  "Your Name"
   git config --global user.email "you@example.com"
   ```

   `gh` is already configured as git's credential helper, so `git push` over
   HTTPS works after `gh auth login`.

## Day-to-day

Interactive Claude session in the terminal:

```sh
./agent rust claude                 # plain session
./agent rust claude --continue      # any claude flags pass through
```

Claude with Remote Control, so you can drive it from your phone:

```sh
./agent rust remote                 # auto-named session, e.g. agent-rust-brave-otter
./agent rust remote "Fix the parser"   # named session
./agent rust attach                 # see the terminal, press space for the QR code
./agent rust stop                   # shut it down
```

`remote` starts a detached container running `claude --remote-control` inside
tmux, so it keeps running after you close SSH to the Mac mini. Open the Claude
app on your phone, tap **Code**, and pick the session, or scan the QR code from
`attach`. Detach from tmux with `Ctrl-b d`. While the remote container is up,
`./agent rust claude` and `./agent rust sh` open extra sessions inside it
rather than starting a second VM, because the home volume can only be mounted
by one container at a time.

If you run Claude under your own supervisor (launchd, systemd, a restart
loop), use `remote-fg` instead: it's identical to `remote` but stays in the
foreground and blocks until the container exits, so the supervisor can
restart it. `./agent rust attach` still works against it while it's running.

```sh
./agent rust remote-fg               # blocks; supervisor restarts on exit
```

Other commands:

```sh
./agent rust sh              # bash shell
./agent rust status          # containers, volumes, images
./agent rust logs            # stdout of the detached container
./agent rust build --no-cache
./agent rust reset-volume    # wipe the home volume (logins, work/, caches)
```

Environment knobs:

| Variable       | Default | Purpose                                              |
| -------------- | ------- | ---------------------------------------------------- |
| `AGENT_CPUS`   | `4`     | CPUs for the VM                                      |
| `AGENT_MEMORY` | `8g`    | RAM for the VM (Rust builds want more than the 1g default) |
| `AGENT_MOUNT`  | unset   | Host directory to bind-mount at `/home/agent/work/host` |

## Layout

```
agent                       launcher script (./agent <container> <command>)
containers/rust/
  Dockerfile                image definition
  entrypoint.sh             root: seeds/chowns the home volume, drops to `agent`
  claude-remote.sh          runs claude --remote-control inside tmux, keeps VM alive
```

Persistent state lives in the named volume `agent-rust-home`, mounted at
`/home/agent`. That covers `~/.claude` and `~/.claude.json` (Claude login,
settings, sessions), `~/.config/gh`, `~/.gitconfig`, `~/.cargo` (crate cache),
and `~/work` (your repos). The image itself is stateless: rebuild it to update
Claude Code, `gh`, or the Rust toolchain.

## Adding another container

Create `containers/<name>/Dockerfile` (copy `rust/` as a starting point and keep
`entrypoint.sh` + `claude-remote.sh`), then `./agent <name> build`. The launcher
derives the image, container and volume names from `<name>`.
