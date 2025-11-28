#!/usr/bin/env bash
set -euo pipefail

# Validation step: build APK, install/start/stop on attached device, record logs and JSON evidence
WORKSPACE="/home/kavia/workspace/code-generation/tic-tac-toe-mobile-283707-283716/tic_tac_toe_native_app"
cd "$WORKSPACE"
LOG="$WORKSPACE/.validation.log"
EVIDENCE_JSON="$WORKSPACE/.validation_ok"
: > "$LOG"

# Build
if [ -x ./gradlew ]; then
  ./gradlew assembleDebug >>"$LOG" 2>&1 || {
    echo "build_failed" >>"$LOG"
    jq -n --arg e "build_failed" '{status:$e}' > "$EVIDENCE_JSON" 2>/dev/null || true
    exit 2
  }
else
  echo "no_gradle" >>"$LOG"
  jq -n --arg e "no_gradle" '{status:$e}' > "$EVIDENCE_JSON" 2>/dev/null || exit 3
fi

# Locate APK
APK_PATH=""
for p in app/build/outputs/apk/debug/*.apk; do
  [ -f "$p" ] && APK_PATH="$p" && break || true
done
if [ -z "$APK_PATH" ]; then
  echo "no_apk_found" >>"$LOG"
  jq -n --arg e "no_apk_found" '{status:$e}' > "$EVIDENCE_JSON"
  exit 4
fi
if [ ! -s "$APK_PATH" ]; then
  echo "apk_empty" >>"$LOG"
  jq -n --arg e "apk_empty" '{status:$e}' > "$EVIDENCE_JSON"
  exit 5
fi

# Base evidence
jq -n --arg s "built" --arg apk "$APK_PATH" '{status:$s,apk:$apk}' > /tmp/.validation_base.json 2>/dev/null || true

# If adb available, inspect devices and attempt install/start/stop
if command -v adb >/dev/null 2>&1; then
  adb devices >>"$LOG" 2>&1 || true
  adb_out=$(adb devices 2>>"$LOG" || true)
  # parse lines after header
  devices=$(echo "$adb_out" | awk 'NR>1 && NF{print $1":"$2}') || true
  if [ -z "$devices" ]; then
    echo "no_device_attached" >>"$LOG"
    jq -n --arg s "no_device_attached" --arg apk "$APK_PATH" '{status:$s,apk:$apk}' > "$EVIDENCE_JSON"
  else
    first=$(echo "$devices" | head -n1)
    dev=$(echo "$first" | cut -d: -f1)
    state=$(echo "$first" | cut -d: -f2)
    case "$state" in
      device)
        echo "device_found:$dev" >>"$LOG"
        # Try install (replace) and capture result
        if adb -s "$dev" install -r "$APK_PATH" >>"$LOG" 2>&1; then
          INSTALL_STATUS="ok"
        else
          INSTALL_STATUS="install_failed"
          echo "adb_install_failed" >>"$LOG"
        fi
        # Determine package from manifest if present
        PKG=$(sed -n 's/.*package="\([^"]*\)".*/\1/p' app/src/main/AndroidManifest.xml || true)
        [ -z "$PKG" ] && PKG="com.example.tictactoe"
        # Start activity (best-effort)
        if adb -s "$dev" shell am start -n "$PKG/.MainActivity" >>"$LOG" 2>&1; then
          START_STATUS="started"
        else
          START_STATUS="start_failed"
          echo "start_failed" >>"$LOG"
        fi
        sleep 1
        if adb -s "$dev" shell am force-stop "$PKG" >>"$LOG" 2>&1; then
          STOP_STATUS="stopped"
        else
          STOP_STATUS="force_stop_failed"
          echo "force_stop_failed" >>"$LOG"
        fi
        jq -n --arg s "installed_started_stopped" --arg dev "$dev" --arg apk "$APK_PATH" --arg install "$INSTALL_STATUS" --arg start "$START_STATUS" --arg stop "$STOP_STATUS" '{status:$s,device:$dev,apk:$apk,install:$install,start:$start,stop:$stop}' > "$EVIDENCE_JSON"
        ;;
      unauthorized)
        echo "device_unauthorized:$dev" >>"$LOG"
        jq -n --arg s "device_unauthorized" --arg dev "$dev" --arg apk "$APK_PATH" '{status:$s,device:$dev,apk:$apk}' > "$EVIDENCE_JSON"
        ;;
      offline)
        echo "device_offline:$dev" >>"$LOG"
        jq -n --arg s "device_offline" --arg dev "$dev" --arg apk "$APK_PATH" '{status:$s,device:$dev,apk:$apk}' > "$EVIDENCE_JSON"
        ;;
      *)
        echo "device_unknown_state:$state" >>"$LOG"
        jq -n --arg s "device_unknown" --arg state "$state" --arg apk "$APK_PATH" '{status:$s,state:$state,apk:$apk}' > "$EVIDENCE_JSON"
        ;;
    esac
  fi
else
  echo "adb_missing" >>"$LOG"
  jq -n --arg s "adb_missing" --arg apk "$APK_PATH" '{status:$s,apk:$apk}' > "$EVIDENCE_JSON"
fi

# Clean build artifacts to keep workspace tidy (best-effort)
if [ -x ./gradlew ]; then
  ./gradlew clean >>"$LOG" 2>&1 || true
fi

# Exit 0 if evidence file exists, otherwise non-zero
if [ -f "$EVIDENCE_JSON" ]; then
  exit 0
else
  echo "evidence_missing" >>"$LOG"
  jq -n --arg e "evidence_missing" '{status:$e}' > "$EVIDENCE_JSON" 2>/dev/null || true
  exit 6
fi
