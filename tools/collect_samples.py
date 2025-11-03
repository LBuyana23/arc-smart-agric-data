#!/usr/bin/env python3
"""
collect_samples.py

Query the bridge for configured upstreams and force-refresh each source, saving the JSON
responses into tools/samples/<group>__<source>.json for regression and inspection.

Usage (Windows cmd.exe):
  set API_BASE=http://127.0.0.1:5000
  python tools\collect_samples.py

You can also set SAVE_DIR to change the output directory.
"""
import os
import sys
import json
from pathlib import Path

import requests

API_BASE = os.environ.get('API_BASE', 'http://127.0.0.1:5000')
SAVE_DIR = Path(os.environ.get('SAVE_DIR', 'tools/samples'))

SAVE_DIR.mkdir(parents=True, exist_ok=True)


def get_upstreams():
    url = f"{API_BASE}/config/upstreams"
    print(f"GET {url}")
    r = requests.get(url, timeout=10)
    r.raise_for_status()
    return r.json()


def force_refresh(group, source):
    url = f"{API_BASE}/force_refresh/{group}/{source}"
    print(f"POST {url}")
    r = requests.post(url, timeout=20)
    r.raise_for_status()
    return r.json()


def main():
    try:
        cfg = get_upstreams()
    except Exception as e:
        print(f"Failed to fetch upstreams: {e}")
        sys.exit(2)

    # cfg expected shape: { group: [ {name: 'G6', url: '...', ...}, ... ], ... }
    for group, sources in cfg.items():
        if not isinstance(sources, list):
            continue
        for s in sources:
            name = s.get('name') or s.get('id') or s.get('source')
            if not name:
                print(f"Skipping source with no name in group {group}")
                continue
            try:
                payload = force_refresh(group, name)
            except Exception as e:
                print(f"Failed to refresh {group}/{name}: {e}")
                continue
            fname = SAVE_DIR / f"{group}__{name}.json"
            with open(fname, 'w', encoding='utf8') as f:
                json.dump(payload, f, indent=2, ensure_ascii=False)
            print(f"Saved {fname}")


if __name__ == '__main__':
    main()
