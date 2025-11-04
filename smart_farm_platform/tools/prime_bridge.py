import json, urllib.request, urllib.error, ssl, sys

base='https://smart-farm-api-g25w.onrender.com/api'
ctx=ssl.create_default_context()

def get(url):
    req=urllib.request.Request(url, method='GET')
    with urllib.request.urlopen(req, timeout=30, context=ctx) as r:
        return json.load(r)

def post(url):
    req=urllib.request.Request(url, data=b'', method='POST')
    try:
        with urllib.request.urlopen(req, timeout=30, context=ctx) as r:
            try:
                return json.load(r)
            except Exception:
                return r.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        try:
            body = e.read().decode('utf-8')
        except Exception:
            body = '<no body>'
        return {'http_error': e.code, 'msg': body}
    except Exception as e:
        return {'error': str(e)}

try:
    # Prefer using the canonical upstream config which lists groups and their
    # canonical source keys. This avoids guessing variants and hitting unknown
    # source errors on the bridge.
    cfg = get(base + '/config/upstreams')
except Exception as e:
    print(json.dumps({'error': 'failed to fetch /api/config/upstreams', 'exc': str(e)}))
    sys.exit(1)

# cfg is expected to be a dict with 'groups' mapping group->list_of_source_keys
groups_map = cfg.get('groups', {}) if isinstance(cfg, dict) else {}
results = []

def poll_for_cached(group, source, max_attempts=6):
    # Poll /api/<group>/history/<source>?limit=1 and /api/<group>/all to detect
    # whether the bridge has synthesized the cached snapshot for this source.
    for attempt in range(max_attempts):
        try:
            # Check direct per-source history first
            h = get(base + f'/{group}/history/{source}?limit=1')
            if isinstance(h, list) and len(h) > 0:
                return {'cached': True, 'via': 'history', 'rows': len(h)}
            if isinstance(h, dict) and h.get('error'):
                # not yet cached sentinel; continue polling
                pass
        except Exception:
            pass
        try:
            allp = get(base + f'/{group}/all')
            if isinstance(allp, dict) and source in allp:
                val = allp[source]
                if isinstance(val, dict) and 'error' not in val:
                    return {'cached': True, 'via': 'all', 'raw': val}
        except Exception:
            pass
        # backoff: 1s,2s,4s,8s,... up to max_attempts
        time_sleep = 1 << attempt
        try:
            import time
            time.sleep(time_sleep)
        except Exception:
            pass
    return {'cached': False}

for group, keys in groups_map.items():
    # keys should be a list of canonical source ids for this group
    if not isinstance(keys, list):
        continue
    for key in keys:
        uri = f"{base}/force_refresh/{group}/{key}"
        r = post(uri)
        ok = not (isinstance(r, dict) and (r.get('http_error') or r.get('error')))
        results.append({'group': group, 'canonical': key, 'attempted': True, 'result': r, 'accepted': ok})
        if ok:
            # Only poll for cached status if the bridge accepted the refresh
            poll = poll_for_cached(group, key, max_attempts=6)
            results[-1]['cached'] = poll
        else:
            results[-1]['cached'] = {'cached': False}

# Also capture any groups discovered in /api/all as a fallback check
try:
    allp = get(base + '/all')
    debug_all = {'type': type(allp).__name__, 'keys': list(allp.keys()) if isinstance(allp, dict) else None}
except Exception as e:
    debug_all = {'error': str(e)}

out = {'timestamp': __import__('datetime').datetime.utcnow().isoformat() + 'Z', 'base': base, 'config': cfg, 'results': results, 'all_snapshot': debug_all}
print(json.dumps(out, indent=2, ensure_ascii=False))
