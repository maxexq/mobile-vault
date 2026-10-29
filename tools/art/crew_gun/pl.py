"""PixelLab helpers for the crew gun animation thread (MV-594). Auth is injected by the proxy."""
import base64, io, json, os, sys, time, urllib.request, urllib.error
from PIL import Image
API = 'https://api.pixellab.ai/v2'
REF = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../../docs/art/crew-style-reference/')

def call(method, path, body=None):
    for attempt in range(4):
        try:
            r = urllib.request.Request(API + path, method=method,
                data=json.dumps(body).encode() if body is not None else None,
                headers={'Content-Type': 'application/json', 'Authorization': 'Bearer x'})
            return json.load(urllib.request.urlopen(r, timeout=120))
        except urllib.error.HTTPError as e:
            msg = e.read().decode()[:500]
            if e.code in (502, 503, 504) and attempt < 3:
                time.sleep(5); continue
            raise SystemExit(f'{e.code} {msg}')

def b64(img):
    buf = io.BytesIO(); img.save(buf, 'PNG')
    return {'type': 'base64', 'base64': base64.b64encode(buf.getvalue()).decode()}

def unb64(s):
    if isinstance(s, dict): s = s.get('base64', '')
    if s.startswith('data:'): s = s.split(',', 1)[1]
    return Image.open(io.BytesIO(base64.b64decode(s))).convert('RGBA')

def job(jid, every=5):
    while True:
        j = call('GET', f'/background-jobs/{jid}')
        if j.get('status') in ('completed', 'failed'): return j
        time.sleep(every)

def balance():
    return call('GET', '/balance')['subscription']['generations']
