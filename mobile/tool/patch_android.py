"""Adds what this app needs to the Android project that `flutter create` generates.

Run once from the mobile folder after `flutter create --platforms=android .`
(the GitHub build does this for you). Safe to run again: it skips changes already made.
"""
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
xml = manifest.read_text(encoding="utf-8")

# Release builds need this to reach Supabase (debug builds get it automatically)
internet = '<uses-permission android:name="android.permission.INTERNET"/>'
if internet not in xml:
    xml = xml.replace("<application", f"{internet}\n    <application", 1)

# Name under the app icon
xml = xml.replace('android:label="hotel_reservation"', 'android:label="Sample Bay Hotel"')

# Tapping the sign-in link in the email opens the app (matches authRedirect in lib/config.dart)
deep_link = """
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="com.samplebayhotel.app" android:host="login-callback"/>
            </intent-filter>
        </activity>"""
if "com.samplebayhotel.app" not in xml:
    xml = xml.replace("\n        </activity>", deep_link, 1)

# Lets the app open web pages (payment checkout) in the browser on Android 11+
web_query = """<queries>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>"""
if 'android:scheme="https"' not in xml:
    if "<queries>" in xml:
        xml = xml.replace("<queries>", web_query, 1)
    else:
        xml = xml.replace("</manifest>", f"    {web_query}\n    </queries>\n</manifest>", 1)

manifest.write_text(xml, encoding="utf-8")
print(xml)
