#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/tic-tac-toe-mobile-283707-283716/tic_tac_toe_native_app"
cd "$WORKSPACE" || (mkdir -p "$WORKSPACE" && cd "$WORKSPACE")
# Idempotent: skip if project appears present
if [ -f "$WORKSPACE/settings.gradle" ] || [ -f "$WORKSPACE/build.gradle" ]; then exit 0; fi
cat > settings.gradle <<'S'
rootProject.name = 'tic_tac_toe_native_app'
include ':app'
S
cat > build.gradle <<'G'
buildscript { repositories { google(); mavenCentral() } dependencies { classpath 'com.android.tools.build:gradle:7.4.2' } }
allprojects { repositories { google(); mavenCentral() } }
G
# Create module directories (do not include filenames in mkdir)
mkdir -p app/src/main/java/com/example/tictactoe app/src/main/res/layout app/src/test/java/com/example/tictactoe
cat > app/build.gradle <<'A'
apply plugin: 'com.android.application'
android {
  compileSdkVersion 33
  defaultConfig { applicationId 'com.example.tictactoe'; minSdkVersion 21; targetSdkVersion 33; versionCode 1; versionName '1.0' }
  buildTypes { release { minifyEnabled false } }
}
dependencies { implementation fileTree(dir: 'libs', include: ['*.jar']) }
A
# Manifest
mkdir -p app/src/main
cat > app/src/main/AndroidManifest.xml <<'M'
<manifest package="com.example.tictactoe" xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:label="tic-tac-toe">
    <activity android:name=".MainActivity">
      <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
      </intent-filter>
    </activity>
  </application>
</manifest>
M
# Minimal Activity
cat > app/src/main/java/com/example/tictactoe/MainActivity.java <<'J'
package com.example.tictactoe;
import android.app.Activity; import android.os.Bundle; import android.widget.TextView;
public class MainActivity extends Activity {
  @Override protected void onCreate(Bundle s) { super.onCreate(s); TextView v=new TextView(this); v.setText("tic-tac-toe placeholder"); setContentView(v); }
}
J
# Ensure gradle wrapper
if command -v gradle >/dev/null 2>&1; then
  # try to generate wrapper for consistent version; tolerate failure
  gradle wrapper --gradle-version 7.6 >/dev/null 2>&1 || true
else
  mkdir -p gradle/wrapper
  cat > gradle/wrapper/gradle-wrapper.properties <<'P'
distributionUrl=https\://services.gradle.org/distributions/gradle-7.6-bin.zip
P
  # download wrapper jar with retries
  RETRIES=3; SLEEP=2; i=0
  while [ $i -lt $RETRIES ]; do
    if curl --fail --connect-timeout 10 -sSL -o gradle/wrapper/gradle-wrapper.jar https://repo1.maven.org/maven2/org/gradle/wrapper/gradle-wrapper/7.6/gradle-wrapper-7.6.jar; then break; fi
    i=$((i+1)); sleep $SLEEP
  done
  if [ ! -f gradle/wrapper/gradle-wrapper.jar ]; then echo "Failed to obtain gradle wrapper jar" >&2; exit 10; fi
  if [ ! -f gradlew ]; then
    cat > gradlew <<'W'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd -P)"
exec java -jar "$DIR/gradle/wrapper/gradle-wrapper.jar" "$@"
W
    chmod +x gradlew
  fi
fi
# Validate wrapper
if [ -x ./gradlew ]; then
  ./gradlew --version >/dev/null 2>&1 || { echo "gradle wrapper not functional" >&2; exit 11; }
fi
# Start helper
cat > "$WORKSPACE/start.sh" <<'S'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [ -x ./gradlew ]; then ./gradlew assembleDebug; else echo "No gradlew available; install gradle or use system gradle"; fi
S
chmod +x "$WORKSPACE/start.sh"
