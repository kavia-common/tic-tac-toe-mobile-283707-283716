#!/usr/bin/env bash
set -euo pipefail
# testing step: add junit test conservatively and run Gradle config-check and tests
WORKSPACE="/home/kavia/workspace/code-generation/tic-tac-toe-mobile-283707-283716/tic_tac_toe_native_app"
cd "$WORKSPACE"
# create test dir and a tiny JUnit test
mkdir -p app/src/test/java/com/example/tictactoe
cat > app/src/test/java/com/example/tictactoe/MainTest.java <<'T'
package com.example.tictactoe;
import org.junit.Test; import static org.junit.Assert.*;
public class MainTest { @Test public void sample() { assertTrue(true); } }
T
# safely insert junit dependency and testOptions using Python to avoid corrupting build.gradle
python3 - <<'PY'
import io,sys,os,re
p='app/build.gradle'
if not os.path.exists(p):
    print('build.gradle not found, aborting', file=sys.stderr)
    sys.exit(2)
with open(p,'r',encoding='utf-8') as f:
    s=f.read()
changed=False
if 'junit:junit:4.13.2' not in s:
    m=re.search(r'(^\s*dependencies\s*\{)', s, flags=re.M)
    if m:
        idx=m.end()
        s=s[:idx]+"\n    testImplementation \"junit:junit:4.13.2\""+s[idx:]
    else:
        s += "\n// test deps added by setup\ndependencies { testImplementation \"junit:junit:4.13.2\" }\n"
    changed=True
# add testOptions only if clear android block exists and testOptions not present
if 'testOptions' not in s:
    m=re.search(r'(^\s*android\s*\{)', s, flags=re.M)
    if m:
        idx=m.end()
        s=s[:idx]+"\n  testOptions { unitTests { includeAndroidResources = false } }\n"+s[idx:]
        changed=True
if changed:
    with open(p,'w',encoding='utf-8') as f:
        f.write(s)
print('build.gradle updated' if changed else 'no changes to build.gradle')
PY
LOG="$WORKSPACE/.validation.log"
: > "$LOG"
# Run configuration dry-run and tests, capturing output
if [ -x ./gradlew ]; then
  ./gradlew assembleDebug --dry-run >>"$LOG" 2>&1 || { echo "gradle_config_failed" >>"$LOG"; exit 4; }
  ./gradlew test >>"$LOG" 2>&1 || { echo "tests_failed" >>"$LOG"; exit 5; }
else
  echo "gradlew missing" >>"$LOG"; exit 6
fi
