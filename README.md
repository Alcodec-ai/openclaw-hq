# OpenClaw HQ Dashboard

Web-based management dashboard for [OpenClaw](https://github.com/openclaw) multi-agent platform. Monitor agents, manage models, configure platform bindings, and control the gateway — all from a single UI.

## Prerequisites

- **OpenClaw CLI** installed and configured (`~/.openclaw/openclaw.json`)
- **OpenClaw Gateway** running (the dashboard reads its config and logs)
- **Python 3.10+** (for manual install) or **Docker** (for container install)

## Quick Start

### Docker (recommended)

```bash
docker compose up -d
```

Dashboard will be available at `http://localhost:7842`.

The compose file mounts `~/.openclaw` so the dashboard can read/write OpenClaw config.

### Manual Install

```bash
./run.sh
```

This creates a virtualenv, installs dependencies, and starts the dashboard.

## Installation Options

### Docker Build

```bash
docker build -t openclaw-dashboard .
docker run --rm --network host -v ~/.openclaw:/home/openclaw/.openclaw openclaw-dashboard
```

### install.sh (systemd / launchd)

```bash
chmod +x install.sh
./install.sh
```

The installer will:
1. Check for Python 3.10+
2. Create a virtualenv and install dependencies
3. Optionally install a system service:
   - **Linux**: systemd user service (`openclaw-dashboard.service`)
   - **macOS**: launchd agent (`com.openclaw.dashboard.plist`)

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `OPENCLAW_DASH_PORT` | `7842` | HTTP port for the dashboard |

## API Reference

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/status` | Gateway status (active, pid, memory, uptime) |
| GET | `/api/agents` | List all agents with status and platform |
| GET | `/api/agent/<id>` | Agent detail (sessions, tokens, messages, platform) |
| POST | `/api/agent/<id>/model` | Change agent's primary model |
| POST | `/api/agent/<id>/platform` | Change agent's platform binding |
| GET | `/api/platforms` | List supported platforms |
| GET | `/api/models/available` | List available model IDs |
| GET | `/api/models` | Default model config |
| POST | `/api/defaults/model` | Update default primary/fallback models |
| POST | `/api/defaults/compaction` | Update compaction mode |
| GET | `/api/providers` | List model providers (masked keys) |
| POST | `/api/providers` | Add a new provider |
| POST | `/api/providers/<name>/update` | Update provider config |
| POST | `/api/providers/<name>/delete` | Delete a provider |
| GET | `/api/channels` | Telegram channel status |
| POST | `/api/channel/<name>/toggle` | Enable/disable a channel |
| POST | `/api/channel/<name>/settings` | Update channel policies |
| GET | `/api/settings` | Full settings overview |
| POST | `/api/gateway/start` | Start gateway service |
| POST | `/api/gateway/stop` | Stop gateway service |
| POST | `/api/gateway/restart` | Restart gateway service |
| GET | `/api/sessions` | List all sessions |
| POST | `/api/task` | Send a message to an agent |
| GET | `/api/logs/recent` | Recent gateway logs |
| GET | `/events` | SSE stream of live logs |
| GET | `/api/md-backup/status` | Backup config and last result |
| POST | `/api/md-backup/settings` | Update backup settings |
| POST | `/api/md-backup/export` | Trigger manual backup |
| GET | `/api/browse-dirs` | Browse directories (for backup picker) |
| POST | `/api/mkdir` | Create a directory |
