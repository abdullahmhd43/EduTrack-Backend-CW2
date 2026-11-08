#!/usr/bin/env python3
"""Run once after `flutter create` to configure the Android project for EduTrack.
 - adds INTERNET + ACCESS_NETWORK_STATE permissions (release builds do NOT get INTERNET by default!)
 - allows http:// (cleartext) because the demo API runs over plain HTTP on the LAN
 - sets the app label to "EduTrack"
 - raises minSdk to 23 (needed by flutter_secure_storage)
Usage (from the frontend folder):  python3 tool/patch_android.py
"""
import re, pathlib, sys

manifest = pathlib.Path('android/app/src/main/AndroidManifest.xml')
if not manifest.exists():
    sys.exit('Run `flutter create` first (android/ folder not found).')
s = manifest.read_text()
if 'android.permission.INTERNET' not in s:
    s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>\n    <application', 1)
if 'usesCleartextTraffic' not in s:
    s = s.replace('<application', '<application\n        android:usesCleartextTraffic="true"', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="EduTrack"', s, count=1)
manifest.write_text(s)
print('patched', manifest)

for name in ('build.gradle', 'build.gradle.kts'):
    g = pathlib.Path('android/app') / name
    if g.exists():
        t = g.read_text()
        t2 = re.sub(r'minSdk(Version)?\s*=?\s*(flutter\.minSdkVersion|\d+)', lambda m: f'minSdk{m.group(1) or ""} = 23' if name.endswith('kts') else f'minSdkVersion 23', t)
        g.write_text(t2)
        print('patched', g)
