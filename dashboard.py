import json
import os
import platform
import re
import shutil
import subprocess
import threading
import time
from datetime import datetime
from pathlib import Path

from flask import Flask, Response, jsonify, render_template, request

app = Flask(__name__)
IS_MACOS = platform.system() == 'Darwin'
SERVICE_NAME = 'com.openclaw.gateway' if IS_MACOS else 'openclaw-gateway'

CONFIG_PATH = Path.home() / '.openclaw' / 'openclaw.json'
LOG_DIR = Path('/tmp/openclaw')
AGENTS_DIR = Path.home() / '.openclaw' / 'agents'

_backup_timer = None
_backup_lock = threading.Lock()

BOT_NAMES = {
    'kate': '@KateAdler_Bot',
    'main': '@Tom_MiniM_Bot',
    'nova': '@Nova_blm_bot',
    'raven': '@Raven_Bot',
}


def load_config():
    try:
        return json.loads(CONFIG_PATH.read_text())
    except Exception:
        return {}


def save_config(cfg):
    CONFIG_PATH.write_text(json.dumps(cfg, indent=2, ensure_ascii=False))


def run_cmd(cmd, timeout=10):
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout,
            env={**os.environ}
        )
        return result.stdout + result.stderr
    except Exception as e:
        return str(e)


def today_log():
    today = datetime.now().strftime('%Y-%m-%d')
    return LOG_DIR / f'openclaw-{today}.log'


def perform_md_backup(target_path):
    """Copy all .md files from each agent's 'agent' subdirectory to target."""
    target = Path(target_path)
    if not target.exists():
        return {'ok': False, 'error': 'Target path does not exist'}
    test_file = target / '.openclaw_write_test'
    try:
        test_file.write_text('test')
        test_file.unlink()
    except OSError:
        return {'ok': False, 'error': 'Target path is not writable'}

    cfg = load_config()
    agents_list = cfg.get('agents', {}).get('list', [])
    files_copied = 0
    agents_done = []
    errors = []

    for agent in agents_list:
        agent_id = agent['id']
        agent_src = AGENTS_DIR / agent_id / 'agent'
        if not agent_src.is_dir():
            continue
        agent_copied = 0
        for md_file in agent_src.rglob('*.md'):
            rel = md_file.relative_to(agent_src)
            dest = target / 'agents' / agent_id / rel
            try:
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(str(md_file), str(dest))
                files_copied += 1
                agent_copied += 1
            except Exception as e:
                errors.append(f'{agent_id}/{rel}: {e}')
        if agent_copied > 0:
            agents_done.append(agent_id)

    timestamp = datetime.now().isoformat(timespec='seconds')
    result = {
        'ok': len(errors) == 0,
        'files_copied': files_copied,
        'agents': agents_done,
        'errors': errors,
        'timestamp': timestamp,
    }

    cfg = load_config()
    backup_cfg = cfg.setdefault('md_backup', {})
    backup_cfg['last_backup'] = timestamp
    backup_cfg['last_result'] = {'files_copied': files_copied, 'agents': agents_done, 'ok': result['ok']}
    save_config(cfg)

    return result


def _auto_backup_tick():
    """Timer callback: perform backup and reschedule."""
    cfg = load_config()
    backup_cfg = cfg.get('md_backup', {})
    target = backup_cfg.get('path', '')
    if target and backup_cfg.get('enabled', False):
        with _backup_lock:
            perform_md_backup(target)
    _restart_backup_timer()


def _restart_backup_timer():
    """Cancel existing timer and start a new one if auto-backup is enabled."""
    global _backup_timer
    if _backup_timer is not None:
        _backup_timer.cancel()
        _backup_timer = None

    cfg = load_config()
    backup_cfg = cfg.get('md_backup', {})
    if backup_cfg.get('enabled', False) and backup_cfg.get('path', ''):
        interval = backup_cfg.get('interval_minutes', 60) * 60
        _backup_timer = threading.Timer(interval, _auto_backup_tick)
        _backup_timer.daemon = True
        _backup_timer.start()


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/api/status')
def api_status():
    active = False
    pid = memory = uptime_raw = None

    if IS_MACOS:
        # macOS: check via launchctl or pgrep
        output = run_cmd(['pgrep', '-f', 'openclaw.*gateway'])
        if output.strip():
            active = True
            pid = output.strip().splitlines()[0]
            # Get memory via ps
            ps_out = run_cmd(['ps', '-o', 'rss=', '-p', pid])
            try:
                rss_kb = int(ps_out.strip())
                memory = f"{rss_kb // 1024}M" if rss_kb > 1024 else f"{rss_kb}K"
            except Exception:
                pass
            # Get start time
            ps_time = run_cmd(['ps', '-o', 'lstart=', '-p', pid])
            if ps_time.strip():
                uptime_raw = ps_time.strip()
    else:
        output = run_cmd(['systemctl', '--user', 'status', 'openclaw-gateway'])
        active = 'active (running)' in output

        for line in output.splitlines():
            stripped = line.strip()
            if 'Main PID:' in stripped:
                pid = stripped.split('Main PID:')[1].split()[0]
            elif 'Memory:' in stripped:
                memory = stripped.split('Memory:')[1].strip()
            elif stripped.startswith('Active:') and 'since' in stripped:
                uptime_raw = stripped.split('Active:')[1].strip()

    cfg = load_config()
    version = cfg.get('meta', {}).get('lastTouchedVersion', 'unknown')

    return jsonify({
        'active': active,
        'pid': pid,
        'memory': memory,
        'uptime': uptime_raw,
        'version': version,
    })


@app.route('/api/agents')
def api_agents():
    cfg = load_config()
    agents_list = cfg.get('agents', {}).get('list', [])

    result = []
    for agent in agents_list:
        agent_id = agent['id']
        sessions_file = AGENTS_DIR / agent_id / 'sessions' / 'sessions.json'

        last_activity = None
        active_sessions = 0

        try:
            sessions_data = json.loads(sessions_file.read_text())
            for sess in sessions_data.values():
                updated_at = sess.get('updatedAt', 0)
                if updated_at:
                    ts = datetime.fromtimestamp(updated_at / 1000)
                    if last_activity is None or ts > last_activity:
                        last_activity = ts
                active_sessions += 1
        except Exception:
            pass

        current_task = None
        if last_activity is not None:
            # Find most recent session file
            best_ts = 0
            best_sess = None
            try:
                for sess in sessions_data.values():
                    ts = sess.get('updatedAt', 0)
                    if ts > best_ts:
                        best_ts = ts
                        best_sess = sess
                if best_sess:
                    sf = best_sess.get('sessionFile')
                    if sf:
                        with open(sf) as f:
                            lines = f.read().splitlines()
                        for line in reversed(lines):
                            if not line.strip():
                                continue
                            try:
                                entry = json.loads(line)
                                if entry.get('type') == 'message':
                                    msg = entry.get('message', {})
                                    if msg.get('role') == 'user':
                                        content = msg.get('content', [])
                                        if isinstance(content, list):
                                            for c in content:
                                                if isinstance(c, dict) and c.get('type') == 'text':
                                                    current_task = c.get('text', '')[:120]
                                                    break
                                        elif isinstance(content, str):
                                            current_task = content[:120]
                                        if current_task:
                                            break
                            except Exception:
                                pass
            except Exception:
                pass

        result.append({
            'id': agent_id,
            'name': agent['name'],
            'model': agent.get('model', {}).get('primary', 'unknown'),
            'lastActivity': last_activity.isoformat() if last_activity else None,
            'activeSessions': active_sessions,
            'currentTask': current_task,
        })

    return jsonify(result)


@app.route('/api/sessions')
def api_sessions():
    # Read all agents' session files directly (faster than subprocess)
    sessions = []
    cfg = load_config()
    agents_list = cfg.get('agents', {}).get('list', [])

    for agent in agents_list:
        agent_id = agent['id']
        sessions_file = AGENTS_DIR / agent_id / 'sessions' / 'sessions.json'
        try:
            sessions_data = json.loads(sessions_file.read_text())
            for key, sess in sessions_data.items():
                updated_at = sess.get('updatedAt', 0)
                age_str = ''
                if updated_at:
                    diff = time.time() - updated_at / 1000
                    if diff < 3600:
                        age_str = f"{int(diff/60)}m ago"
                    elif diff < 86400:
                        age_str = f"{int(diff/3600)}h ago"
                    else:
                        age_str = f"{int(diff/86400)}d ago"

                sessions.append({
                    'agent': agent_id,
                    'key': key,
                    'age': age_str,
                    'chatType': sess.get('chatType', 'direct'),
                    'lastChannel': sess.get('lastChannel', ''),
                })
        except Exception:
            pass

    return jsonify(sessions)


@app.route('/api/channels')
def api_channels():
    output = run_cmd(['openclaw', 'channels', 'status'], timeout=20)

    channels = []
    for line in output.splitlines():
        line = line.strip()
        if line.startswith('- Telegram'):
            m = re.search(r'- Telegram (\w+) \((\w+)\):\s*(.*)', line)
            if not m:
                continue
            name, account_id, details = m.group(1), m.group(2), m.group(3)
            parts = [p.strip() for p in details.split(',')]
            enabled = parts[0] == 'enabled' if parts else False
            running = 'running' in parts

            in_ago = out_ago = None
            for p in parts:
                if p.startswith('in:'):
                    in_ago = p[3:]
                elif p.startswith('out:'):
                    out_ago = p[4:]

            channels.append({
                'name': name,
                'accountId': account_id,
                'botName': BOT_NAMES.get(name, f'@{name}_Bot'),
                'enabled': enabled,
                'running': running,
                'lastIn': in_ago,
                'lastOut': out_ago,
                'details': details,
            })

    # Fall back to config if subprocess failed
    if not channels:
        cfg = load_config()
        accounts = cfg.get('channels', {}).get('telegram', {}).get('accounts', {})
        for name, acc in accounts.items():
            channels.append({
                'name': name,
                'accountId': name,
                'botName': BOT_NAMES.get(name, f'@{name}_Bot'),
                'enabled': acc.get('enabled', False),
                'running': False,
                'lastIn': None,
                'lastOut': None,
                'details': 'config only',
            })

    return jsonify(channels)


@app.route('/api/models')
def api_models():
    cfg = load_config()
    defaults = cfg.get('agents', {}).get('defaults', {})
    primary = defaults.get('model', {}).get('primary', '')
    fallbacks = defaults.get('model', {}).get('fallbacks', [])

    # Gather provider info
    providers_cfg = cfg.get('models', {}).get('providers', {})
    provider_names = list(providers_cfg.keys())

    return jsonify({
        'primary': primary,
        'fallbacks': fallbacks,
        'providers': provider_names,
    })


def _mask_key(key):
    """Mask an API key, showing only first 4 and last 4 chars."""
    if not key or len(key) <= 12:
        return '****' if key else ''
    return key[:4] + '*' * (len(key) - 8) + key[-4:]


@app.route('/api/providers')
def api_providers():
    """List all model providers with masked API keys."""
    cfg = load_config()
    providers = cfg.get('models', {}).get('providers', {})
    result = {}
    for name, pcfg in providers.items():
        models = []
        for m in pcfg.get('models', []):
            if isinstance(m, str):
                models.append(m)
            elif isinstance(m, dict) and 'id' in m:
                models.append(m['id'])
        result[name] = {
            'apiKey': _mask_key(pcfg.get('apiKey', '')),
            'hasKey': bool(pcfg.get('apiKey')),
            'baseUrl': pcfg.get('baseUrl', ''),
            'models': models,
        }
    return jsonify(result)


@app.route('/api/providers', methods=['POST'])
def api_providers_add():
    """Add a new provider."""
    data = request.get_json() or {}
    name = data.get('name', '').strip()
    if not name:
        return jsonify({'error': 'provider name required'}), 400

    cfg = load_config()
    providers = cfg.setdefault('models', {}).setdefault('providers', {})
    if name in providers:
        return jsonify({'error': 'provider already exists'}), 409

    provider = {}
    if data.get('apiKey', '').strip():
        provider['apiKey'] = data['apiKey'].strip()
    if data.get('baseUrl', '').strip():
        provider['baseUrl'] = data['baseUrl'].strip()
    provider['models'] = []
    for m in data.get('models', []):
        m = m.strip() if isinstance(m, str) else ''
        if m:
            provider['models'].append(m)

    providers[name] = provider
    save_config(cfg)
    return jsonify({'ok': True, 'name': name})


@app.route('/api/providers/<name>/update', methods=['POST'])
def api_provider_update(name):
    """Update a provider's API key, base URL, or models."""
    data = request.get_json() or {}
    cfg = load_config()
    providers = cfg.get('models', {}).get('providers', {})
    if name not in providers:
        return jsonify({'error': 'provider not found'}), 404

    pcfg = providers[name]

    if 'apiKey' in data:
        key = data['apiKey'].strip()
        if key and '*' not in key:
            pcfg['apiKey'] = key
        elif not key:
            pcfg.pop('apiKey', None)

    if 'baseUrl' in data:
        url = data['baseUrl'].strip()
        if url:
            pcfg['baseUrl'] = url
        else:
            pcfg.pop('baseUrl', None)

    if 'models' in data and isinstance(data['models'], list):
        pcfg['models'] = [m.strip() for m in data['models'] if isinstance(m, str) and m.strip()]

    save_config(cfg)
    return jsonify({'ok': True})


@app.route('/api/providers/<name>/delete', methods=['POST'])
def api_provider_delete(name):
    """Delete a provider."""
    cfg = load_config()
    providers = cfg.get('models', {}).get('providers', {})
    if name not in providers:
        return jsonify({'error': 'provider not found'}), 404

    del providers[name]
    save_config(cfg)
    return jsonify({'ok': True})


@app.route('/api/agent/<agent_id>')
def api_agent_detail(agent_id):
    cfg = load_config()
    agents_list = cfg.get('agents', {}).get('list', [])
    agent = next((a for a in agents_list if a['id'] == agent_id), None)
    if not agent:
        return jsonify({'error': 'not found'}), 404

    sessions_file = AGENTS_DIR / agent_id / 'sessions' / 'sessions.json'
    sessions_data = {}
    try:
        sessions_data = json.loads(sessions_file.read_text())
    except Exception:
        pass

    best_key = best_sess = None
    best_ts = 0
    for key, sess in sessions_data.items():
        ts = sess.get('updatedAt', 0)
        if ts > best_ts:
            best_ts = ts
            best_key = key
            best_sess = sess

    messages = []
    if best_sess:
        sf = best_sess.get('sessionFile')
        if sf:
            try:
                with open(sf) as f:
                    lines = f.read().splitlines()
                for line in lines[-80:]:
                    if not line.strip():
                        continue
                    try:
                        entry = json.loads(line)
                        if entry.get('type') == 'message' and 'message' in entry:
                            msg = entry['message']
                            role = msg.get('role')
                            if role not in ('user', 'assistant'):
                                continue
                            content = msg.get('content', [])
                            text = ''
                            if isinstance(content, list):
                                for c in content:
                                    if isinstance(c, dict) and c.get('type') == 'text':
                                        text = c.get('text', '')
                                        break
                            elif isinstance(content, str):
                                text = content
                            if text:
                                messages.append({
                                    'role': role,
                                    'text': text[:600],
                                    'timestamp': msg.get('timestamp'),
                                })
                    except Exception:
                        pass
            except Exception:
                pass

    tokens = {}
    if best_sess:
        tokens = {
            'input': best_sess.get('inputTokens', 0),
            'output': best_sess.get('outputTokens', 0),
            'total': best_sess.get('totalTokens', 0),
            'context': best_sess.get('contextTokens', 128000),
        }

    return jsonify({
        'id': agent_id,
        'name': agent.get('name', agent_id),
        'model': agent.get('model', {}).get('primary', 'unknown'),
        'sessionCount': len(sessions_data),
        'messages': messages[-20:],
        'tokens': tokens,
    })


@app.route('/api/models/available')
def api_models_available():
    """Return all available model IDs from provider configs."""
    cfg = load_config()
    providers = cfg.get('models', {}).get('providers', {})
    models = set()
    for provider_name, provider_cfg in providers.items():
        # Collect model IDs from provider definitions
        for model_entry in provider_cfg.get('models', []):
            if isinstance(model_entry, str):
                models.add(model_entry)
            elif isinstance(model_entry, dict) and 'id' in model_entry:
                models.add(model_entry['id'])
    # Also add currently used models
    defaults = cfg.get('agents', {}).get('defaults', {})
    primary = defaults.get('model', {}).get('primary', '')
    if primary:
        models.add(primary)
    for fb in defaults.get('model', {}).get('fallbacks', []):
        if fb:
            models.add(fb)
    for agent in cfg.get('agents', {}).get('list', []):
        ap = agent.get('model', {}).get('primary', '')
        if ap:
            models.add(ap)
        for af in agent.get('model', {}).get('fallbacks', []):
            if af:
                models.add(af)
    return jsonify(sorted(models))


@app.route('/api/agent/<agent_id>/model', methods=['POST'])
def api_agent_model(agent_id):
    """Change the primary model for an agent."""
    data = request.get_json() or {}
    model = data.get('model', '').strip()
    if not model:
        return jsonify({'error': 'model required'}), 400

    cfg = load_config()
    agents_list = cfg.get('agents', {}).get('list', [])
    agent = next((a for a in agents_list if a['id'] == agent_id), None)
    if not agent:
        return jsonify({'error': 'agent not found'}), 404

    if 'model' not in agent:
        agent['model'] = {}
    agent['model']['primary'] = model
    save_config(cfg)
    return jsonify({'ok': True, 'model': model})


@app.route('/api/settings')
def api_settings():
    """Return full settings overview."""
    cfg = load_config()
    defaults = cfg.get('agents', {}).get('defaults', {})
    channels_cfg = cfg.get('channels', {}).get('telegram', {})
    accounts = channels_cfg.get('accounts', {})
    gateway = cfg.get('gateway', {})

    return jsonify({
        'defaults': {
            'primary': defaults.get('model', {}).get('primary', ''),
            'fallbacks': defaults.get('model', {}).get('fallbacks', []),
            'compaction': defaults.get('compaction', {}).get('mode', 'safeguard'),
            'workspace': defaults.get('workspace', ''),
        },
        'channels': {
            name: {
                'enabled': acc.get('enabled', False),
                'dmPolicy': acc.get('dmPolicy', 'open'),
                'groupPolicy': acc.get('groupPolicy', 'open'),
                'streamMode': acc.get('streamMode', 'partial'),
                'botName': BOT_NAMES.get(name, f'@{name}_Bot'),
            }
            for name, acc in accounts.items()
        },
        'gateway': {
            'port': gateway.get('port'),
            'mode': gateway.get('mode', 'local'),
            'bind': gateway.get('bind', 'loopback'),
        },
    })


@app.route('/api/defaults/model', methods=['POST'])
def api_defaults_model():
    """Change default primary model and/or fallbacks."""
    data = request.get_json() or {}
    cfg = load_config()
    defaults = cfg.setdefault('agents', {}).setdefault('defaults', {})
    model_cfg = defaults.setdefault('model', {})

    if 'primary' in data:
        model_cfg['primary'] = data['primary'].strip()
    if 'fallbacks' in data and isinstance(data['fallbacks'], list):
        model_cfg['fallbacks'] = [f.strip() for f in data['fallbacks'] if f.strip()]

    save_config(cfg)
    return jsonify({'ok': True, 'primary': model_cfg.get('primary', ''), 'fallbacks': model_cfg.get('fallbacks', [])})


@app.route('/api/defaults/compaction', methods=['POST'])
def api_defaults_compaction():
    """Change compaction mode."""
    data = request.get_json() or {}
    mode = data.get('mode', '').strip()
    if mode not in ('safeguard', 'full', 'off'):
        return jsonify({'error': 'mode must be safeguard, full, or off'}), 400

    cfg = load_config()
    cfg.setdefault('agents', {}).setdefault('defaults', {}).setdefault('compaction', {})['mode'] = mode
    save_config(cfg)
    return jsonify({'ok': True, 'mode': mode})


@app.route('/api/channel/<name>/toggle', methods=['POST'])
def api_channel_toggle(name):
    """Enable or disable a telegram channel."""
    cfg = load_config()
    accounts = cfg.get('channels', {}).get('telegram', {}).get('accounts', {})
    if name not in accounts:
        return jsonify({'error': 'channel not found'}), 404

    accounts[name]['enabled'] = not accounts[name].get('enabled', False)
    save_config(cfg)
    return jsonify({'ok': True, 'enabled': accounts[name]['enabled']})


@app.route('/api/channel/<name>/settings', methods=['POST'])
def api_channel_settings(name):
    """Update channel policies."""
    data = request.get_json() or {}
    cfg = load_config()
    accounts = cfg.get('channels', {}).get('telegram', {}).get('accounts', {})
    if name not in accounts:
        return jsonify({'error': 'channel not found'}), 404

    acc = accounts[name]
    for key in ('dmPolicy', 'groupPolicy', 'streamMode'):
        if key in data:
            acc[key] = data[key]

    save_config(cfg)
    return jsonify({'ok': True})


@app.route('/api/gateway/restart', methods=['POST'])
def api_gateway_restart():
    """Restart the openclaw-gateway service."""
    if IS_MACOS:
        run_cmd(['pkill', '-f', 'openclaw.*gateway'], timeout=5)
        time.sleep(1)
        output = run_cmd(['openclaw', 'gateway', 'start'], timeout=15)
    else:
        output = run_cmd(['systemctl', '--user', 'restart', 'openclaw-gateway'], timeout=15)
    return jsonify({'ok': True, 'output': output[:500]})


@app.route('/api/gateway/stop', methods=['POST'])
def api_gateway_stop():
    """Stop the openclaw-gateway service."""
    if IS_MACOS:
        output = run_cmd(['pkill', '-f', 'openclaw.*gateway'], timeout=10)
    else:
        output = run_cmd(['systemctl', '--user', 'stop', 'openclaw-gateway'], timeout=15)
    return jsonify({'ok': True, 'output': output[:500]})


@app.route('/api/gateway/start', methods=['POST'])
def api_gateway_start():
    """Start the openclaw-gateway service."""
    if IS_MACOS:
        output = run_cmd(['openclaw', 'gateway', 'start'], timeout=15)
    else:
        output = run_cmd(['systemctl', '--user', 'start', 'openclaw-gateway'], timeout=15)
    return jsonify({'ok': True, 'output': output[:500]})


@app.route('/api/browse-dirs')
def api_browse_dirs():
    """List subdirectories of a given path for the directory picker."""
    path = request.args.get('path', '').strip() or '/'
    target = Path(path)
    if not target.exists() or not target.is_dir():
        return jsonify({'error': f'Path does not exist: {path}'}), 400
    dirs = []
    try:
        for entry in target.iterdir():
            if not entry.is_dir():
                continue
            if entry.name.startswith('.'):
                continue
            try:
                # Test readability
                list(entry.iterdir())
                dirs.append(entry.name)
            except PermissionError:
                pass
    except PermissionError:
        return jsonify({'error': f'Permission denied: {path}'}), 403
    dirs.sort(key=str.lower)
    parent = str(target.parent) if str(target) != '/' else None
    return jsonify({
        'current': str(target),
        'parent': parent,
        'dirs': dirs,
    })


@app.route('/api/mkdir', methods=['POST'])
def api_mkdir():
    """Create a new directory."""
    data = request.get_json() or {}
    path = data.get('path', '').strip()
    if not path:
        return jsonify({'error': 'path required'}), 400
    target = Path(path)
    try:
        target.mkdir(parents=True, exist_ok=True)
    except PermissionError:
        return jsonify({'error': f'Permission denied: {path}'}), 403
    except Exception as e:
        return jsonify({'error': str(e)}), 400
    return jsonify({'ok': True, 'path': str(target)})


@app.route('/api/md-backup/status')
def api_md_backup_status():
    """Return current md_backup config and last backup info."""
    cfg = load_config()
    backup_cfg = cfg.get('md_backup', {})
    return jsonify({
        'path': backup_cfg.get('path', ''),
        'enabled': backup_cfg.get('enabled', False),
        'interval_minutes': backup_cfg.get('interval_minutes', 60),
        'last_backup': backup_cfg.get('last_backup'),
        'last_result': backup_cfg.get('last_result'),
    })


@app.route('/api/md-backup/settings', methods=['POST'])
def api_md_backup_settings():
    """Save md_backup settings: path, enabled, interval_minutes."""
    data = request.get_json() or {}
    cfg = load_config()
    backup_cfg = cfg.setdefault('md_backup', {})

    if 'path' in data:
        p = data['path'].strip()
        if p:
            target = Path(p)
            if not target.exists():
                return jsonify({'error': f'Path does not exist: {p}'}), 400
            test_file = target / '.openclaw_write_test'
            try:
                test_file.write_text('test')
                test_file.unlink()
            except OSError:
                return jsonify({'error': f'Path is not writable: {p}'}), 400
        backup_cfg['path'] = p

    if 'enabled' in data:
        backup_cfg['enabled'] = bool(data['enabled'])

    if 'interval_minutes' in data:
        backup_cfg['interval_minutes'] = int(data['interval_minutes'])

    save_config(cfg)
    _restart_backup_timer()
    return jsonify({'ok': True})


@app.route('/api/md-backup/export', methods=['POST'])
def api_md_backup_export():
    """Manually trigger an MD file backup."""
    cfg = load_config()
    target = cfg.get('md_backup', {}).get('path', '')
    if not target:
        return jsonify({'error': 'No backup path configured'}), 400
    with _backup_lock:
        result = perform_md_backup(target)
    if not result['ok'] and 'error' in result:
        return jsonify(result), 400
    return jsonify(result)


@app.route('/api/task', methods=['POST'])
def api_task():
    data = request.get_json() or {}
    agent_id = data.get('agent_id', '')
    message = data.get('message', '')
    if not agent_id or not message:
        return jsonify({'error': 'agent_id and message required'}), 400
    output = run_cmd(
        ['openclaw', 'agent', '--agent', agent_id, '--message', message],
        timeout=60,
    )
    return jsonify({'output': output[:2000], 'ok': True})


def _parse_log_line(line):
    line = line.strip()
    if not line:
        return None
    try:
        entry = json.loads(line)
        meta = entry.get('_meta', {})
        message = entry.get('0', '')
        if isinstance(message, dict):
            message = json.dumps(message)
        return {
            'time': entry.get('time', meta.get('date', '')),
            'level': meta.get('logLevelName', 'INFO'),
            'subsystem': meta.get('name', ''),
            'message': str(message)[:600],
        }
    except Exception:
        return None


@app.route('/api/logs/recent')
def api_logs_recent():
    log_file = today_log()
    logs = []
    try:
        lines = log_file.read_text().splitlines()
        for line in lines[-100:]:
            entry = _parse_log_line(line)
            if entry:
                logs.append(entry)
    except Exception:
        pass
    return jsonify(logs)


@app.route('/events')
def events():
    def generate():
        log_file = today_log()
        try:
            size = log_file.stat().st_size
        except Exception:
            size = 0

        while True:
            try:
                # Handle day rollover
                current_log = today_log()
                if current_log != log_file:
                    log_file = current_log
                    size = 0

                current_size = log_file.stat().st_size
                if current_size > size:
                    with open(log_file) as f:
                        f.seek(size)
                        new_content = f.read()
                    size = current_size

                    for line in new_content.splitlines():
                        entry = _parse_log_line(line)
                        if entry:
                            yield f"data: {json.dumps(entry)}\n\n"
            except Exception:
                pass

            time.sleep(1)

    return Response(
        generate(),
        mimetype='text/event-stream',
        headers={'Cache-Control': 'no-cache', 'X-Accel-Buffering': 'no'},
    )


if __name__ == '__main__':
    port = int(os.environ.get('OPENCLAW_DASH_PORT', 7842))
    _restart_backup_timer()
    app.run(host='0.0.0.0', port=port, debug=False, threaded=True)
