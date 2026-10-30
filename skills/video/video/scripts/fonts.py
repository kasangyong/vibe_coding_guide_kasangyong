"""fonts.py: 글꼴 받기, 목록, 임베드.

  python fonts.py get "Black Han Sans" 400          Google Fonts(OFL)에서 TTF를 받는다 -> BlackHanSans-400.ttf
  python fonts.py get Hahmlet 800                    가변 글꼴도 굵기 하나로 고정된 TTF로 받는다
  python fonts.py get Pretendard 900 800 600         Pretendard(OFL)는 jsDelivr npm 배포본에서 받는다
  python fonts.py list                               받아 둔 글꼴
  python fonts.py embed intro.src.html intro.html    /*FONT:BlackHanSans-400*/ 자리에 쓰인 글자만 남긴 woff2(base64)를 넣는다

글꼴 폴더: 환경 변수 VIDEO_FONTS, 없으면 ~/.cache/video-skill/fonts (스킬을 다시 설치해도 남는다).
embed에는 fontTools와 brotli가 필요하다: python -m pip install fonttools brotli
"""
import base64, io, os, re, sys, urllib.error, urllib.request

for _s in (sys.stdout, sys.stderr):  # Windows 콘솔에서 한국어 메시지가 깨지지 않게
    try:
        _s.reconfigure(encoding='utf-8')
    except Exception:
        pass

FONT_DIR = os.environ.get('VIDEO_FONTS') or os.path.join(os.path.expanduser('~'), '.cache', 'video-skill', 'fonts')
PRETENDARD = 'https://cdn.jsdelivr.net/npm/pretendard@1.3.9/dist/public/static/Pretendard-{}.otf'
PRET_W = {100: 'Thin', 200: 'ExtraLight', 300: 'Light', 400: 'Regular', 500: 'Medium',
          600: 'SemiBold', 700: 'Bold', 800: 'ExtraBold', 900: 'Black'}
EXTS = ('.ttf', '.otf', '.woff2', '.woff')


def fetch(url):
    # 오래된 브라우저처럼 보이면 Google Fonts가 woff2 조각 대신 굵기별 TTF 한 파일을 준다
    req = urllib.request.Request(url, headers={'User-Agent': 'curl/8.0'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def get(family, weights):
    os.makedirs(FONT_DIR, exist_ok=True)
    stem = family.replace(' ', '')
    for w in weights or [400]:
        w = int(w)
        if stem.lower() == 'pretendard':
            data, ext = fetch(PRETENDARD.format(PRET_W[w])), '.otf'
        else:
            try:
                css = fetch('https://fonts.googleapis.com/css2?family=%s:wght@%d' % (family.replace(' ', '+'), w)).decode()
            except urllib.error.HTTPError as e:
                sys.exit('Google Fonts에 없는 이름이나 굵기다: %s %d (%s). fonts.google.com 에서 이름과 굵기를 확인할 것' % (family, w, e.code))
            m = re.search(r'url\((https://[^)]+)\)', css)
            if not m:
                sys.exit('Google Fonts에서 찾지 못했다: %s %d\n%s' % (family, w, css[:300]))
            data, ext = fetch(m.group(1)), os.path.splitext(m.group(1))[1] or '.ttf'
        path = os.path.join(FONT_DIR, '%s-%d%s' % (stem, w, ext))
        open(path, 'wb').write(data)
        print('%s  %d KB' % (path, len(data) // 1024))


def find(name):
    for ext in EXTS:
        p = os.path.join(FONT_DIR, name + ext)
        if os.path.exists(p):
            return p
    return None


def embed(src, out):
    from fontTools import subset
    from fontTools.ttLib import TTFont
    html = open(src, encoding='utf8').read()
    keys = sorted(set(re.findall(r'/\*FONT:([A-Za-z0-9_.-]+)\*/', html)))
    missing = [k for k in keys if not find(k)]
    if missing:
        sys.exit('글꼴 파일이 없다: %s\n  폴더: %s\n  예: python fonts.py get "<Family Name>" <weight>' % (', '.join(missing), FONT_DIR))
    # 소스에 나오는 모든 글자 + ASCII. 글자를 바꾸면 다시 embed 해야 한다.
    chars = {c for c in html if ord(c) > 32} | {chr(i) for i in range(33, 127)} | set('•…·▼')
    for k in keys:
        f = TTFont(find(k))
        o = subset.Options(); o.flavor = 'woff2'; o.layout_features = ['*']
        s = subset.Subsetter(o); s.populate(unicodes=[ord(c) for c in chars]); s.subset(f)
        b = io.BytesIO(); f.flavor = 'woff2'; f.save(b)
        d = base64.b64encode(b.getvalue()).decode()
        html = html.replace('/*FONT:%s*/' % k, d)
        print('%-28s %4d KB' % (k, len(b.getvalue()) // 1024))
    open(out, 'w', encoding='utf8').write(html)
    print(len(chars), 'chars ->', out)


def main():
    a = sys.argv[1:]
    if not a or a[0] not in ('get', 'list', 'embed'):
        print(__doc__); sys.exit(1)
    if a[0] == 'get' and len(a) >= 2:
        get(a[1], a[2:])
    elif a[0] == 'list':
        print(FONT_DIR)
        if os.path.isdir(FONT_DIR):
            for n in sorted(os.listdir(FONT_DIR)):
                if n.endswith(EXTS):
                    print('  ' + os.path.splitext(n)[0])
    elif a[0] == 'embed' and len(a) == 3:
        embed(a[1], a[2])
    else:
        print(__doc__); sys.exit(1)


if __name__ == '__main__':
    main()
