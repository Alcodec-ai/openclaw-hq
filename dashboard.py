import json
import os
import re
import subprocess
import time
from datetime import datetime
from pathlib import Path

from flask import Flask, Response, jsonify, render_template, request

app = Flask(__name__)

CONFIG_PATH = Path.home() / '.openclaw' / 'openclaw.json'
LOG_DIR = Path('/tmp/openclaw')
AGENTS_DIR = Path.home() / '.openclaw' / 'agents'

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


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/api/status')
def api_status():
    output = run_cmd(['systemctl', '--user', 'status', 'openclaw-gateway'])
    active = 'active (running)' in output
    pid = memory = uptime_raw = None

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
    app.run(host='0.0.0.0', port=7842, debug=False, threaded=True)
