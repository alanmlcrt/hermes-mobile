import concurrent.futures
import json
import re
import urllib.request
from pathlib import Path

OUT = Path(__file__).parent
SHA = '5eee5d02e85eaad32dfade3030d27fcfad204e72'
FILES = ['hermes_cli/web_routers/files.py', 'hermes_cli/web_routers/profiles.py',
         'hermes_cli/web_routers/chat_ws.py', 'hermes_cli/web_server_files.py',
         'hermes_cli/web_server_chat.py', 'apps/desktop/src/lib/gateway-rpc.ts',
         'gateway/platforms/api_server_runs.py', 'pyproject.toml']

def fetch(path):
    url = f'https://raw.githubusercontent.com/NousResearch/hermes-agent/{SHA}/{path}'
    try:
        body = urllib.request.urlopen(url, timeout=25).read().decode()
        (OUT / path.replace('/', '__')).write_text(body, encoding='utf-8')
        hits = [f'{i}: {line.strip()}' for i, line in enumerate(body.splitlines(), 1)
                if re.search(r'@.*\.(get|post|websocket)|upload|attachment|ticket|version\s*=|requires-python', line, re.I)]
        return {'path': path, 'url': url, 'hits': hits[:35]}
    except Exception as e:
        return {'path': path, 'error': str(e)}

if __name__ == '__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        results = list(pool.map(fetch, FILES))
    (OUT / 'hermes-source-index.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
    print(json.dumps(results, ensure_ascii=False, indent=2))
