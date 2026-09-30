#!/usr/bin/env bash
# Builds the Android app (a WebView wrapper around projects.html) without Gradle.
#
# Needs: JDK 8+, and Android build tools aapt2 / dx (or d8) / zipalign / apksigner
#        (Ubuntu: apt-get install android-sdk-build-tools apksigner)
#        plus an android.jar (API 30+). Set ANDROID_JAR, or it is downloaded.
# Signing: KEYSTORE=/path/to/key.jks KS_PASS=... [KEY_ALIAS=suna] ./android/build.sh
#          Always sign with the same keystore, or phones refuse the update.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUT="$HERE/build"
BT="${BUILD_TOOLS:-/usr/lib/android-sdk/build-tools/29.0.3}"
AAPT2="${AAPT2:-$(command -v aapt2 || echo "$BT/aapt2")}"
DX="${DX:-$BT/dx}"
ZIPALIGN="${ZIPALIGN:-$(command -v zipalign || echo "$BT/zipalign")}"
APKSIGNER="${APKSIGNER:-$(command -v apksigner || echo "$BT/apksigner")}"
KEY_ALIAS="${KEY_ALIAS:-suna}"
: "${KEYSTORE:?set KEYSTORE to the signing keystore}"
: "${KS_PASS:?set KS_PASS to the keystore password}"

ANDROID_JAR="${ANDROID_JAR:-$OUT/android.jar}"
mkdir -p "$OUT"
if [ ! -f "$ANDROID_JAR" ]; then
  echo "downloading android.jar (API 30)"
  curl -fsSL -o "$ANDROID_JAR" https://raw.githubusercontent.com/Sable/android-platforms/master/android-30/android.jar
fi

rm -rf "$OUT/assets" "$OUT/res" "$OUT/gen" "$OUT/classes" "$OUT"/*.apk "$OUT"/*.dex
WWW="$OUT/assets/www"
mkdir -p "$WWW/fonts" "$OUT/res" "$OUT/gen" "$OUT/classes"

# ---- web files (the same pages as the website, with fonts bundled and no service worker) ----
cp "$ROOT/index.html" "$ROOT/projects.html" "$ROOT/mini-logo.png" "$ROOT/icon-192.png" "$ROOT/icon-512.png" "$ROOT/manifest.json" "$WWW/"
cp "$HERE"/fonts/* "$WWW/fonts/"
cp "$HERE/fonts.css" "$WWW/fonts.css"
python3 - "$WWW" <<'PY'
import re, sys, os
www = sys.argv[1]
SW = re.compile(r"\s*if \('serviceWorker' in navigator\) \{\s*window\.addEventListener\('load', function \(\) \{\s*navigator\.serviceWorker\.register\('sw\.js'\)\.catch\(function \(\) \{\}\);\s*\}\);\s*\}", re.S)
for name in ('projects.html', 'index.html'):
    p = os.path.join(www, name)
    s = open(p, encoding='utf-8').read()
    s, n = SW.subn('', s)
    assert n == 1, (name, 'service worker block not found')
    if name == 'projects.html':
        # swap remote font stylesheets for the bundled copies
        s, n = re.subn(r'<link rel="preconnect"[^>]*>\s*<link rel="preconnect"[^>]*>\s*<link rel="stylesheet" href="https://fonts\.googleapis\.com[^>]*>\s*<link rel="stylesheet" href="https://cdn\.jsdelivr\.net[^>]*>',
                       '<link rel="stylesheet" href="fonts.css">', s)
        assert n == 1, 'font links not found'
    open(p, 'w', encoding='utf-8').write(s)
PY

# ---- resources + manifest ----
"$AAPT2" compile --dir "$HERE/res" -o "$OUT/res/res.zip"
"$AAPT2" link -o "$OUT/unsigned.apk" -I "$ANDROID_JAR" \
  --manifest "$HERE/AndroidManifest.xml" --java "$OUT/gen" \
  --min-sdk-version 24 --target-sdk-version 34 \
  -A "$OUT/assets" "$OUT/res/res.zip" --auto-add-overlay

# ---- code ----
find "$HERE/src" "$OUT/gen" -name '*.java' > "$OUT/sources.txt"
javac -nowarn -source 8 -target 8 -encoding UTF-8 -bootclasspath "$ANDROID_JAR" -cp "$ANDROID_JAR" \
  -d "$OUT/classes" @"$OUT/sources.txt" 2>&1 | grep -v "bootstrap class path\|source value 8\|target value 8\|To suppress warnings\|^warning: \[options\]\|^[0-9]* warning" || true
[ -f "$OUT/classes/com/sunasouvenir/planner/MainActivity.class" ] || { echo "javac failed"; exit 1; }
"$DX" --dex --min-sdk-version=24 --output="$OUT/classes.dex" "$OUT/classes"
(cd "$OUT" && zip -q -j unsigned.apk classes.dex)

# ---- align + sign ----
"$ZIPALIGN" -f -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"
"$APKSIGNER" sign --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" --ks-key-alias "$KEY_ALIAS" \
  --min-sdk-version 24 --out "$OUT/suna-souvenir.apk" "$OUT/aligned.apk"
"$APKSIGNER" verify --verbose "$OUT/suna-souvenir.apk" | head -5
echo "APK: $OUT/suna-souvenir.apk ($(du -h "$OUT/suna-souvenir.apk" | cut -f1))"
