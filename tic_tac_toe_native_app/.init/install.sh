#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/tic-tac-toe-mobile-283707-283716/tic_tac_toe_native_app"
# install packaging tools idempotently
sudo apt-get update -q && sudo apt-get install -y --no-install-recommends unzip zip >/dev/null 2>&1 || true
cd "$WORKSPACE"
# make gradlew executable if present
if [ -f ./gradlew ]; then
  chmod +x ./gradlew || sudo chmod +x ./gradlew
fi
# Ensure wrapper files readable/executable by all so non-root can run the wrapper
if [ -d gradle/wrapper ]; then
  sudo chmod -R a+rX gradle/wrapper || true
fi
# Validate java availability
if ! command -v java >/dev/null 2>&1; then
  echo "ERROR: java not found on PATH. Install OpenJDK 17 or 11 and retry." >&2
  exit 2
fi
# Validate sdkmanager availability
SDKMGR="/opt/android-sdk/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$SDKMGR" ]; then
  echo "ERROR: sdkmanager not found at $SDKMGR. Ensure Android command-line tools are installed under /opt/android-sdk/cmdline-tools/latest." >&2
  exit 3
fi
# Quick run check: ensure gradlew runs --version (non-failing if gradlew missing)
if [ -f ./gradlew ]; then
  # run gradlew --version but avoid noisy output; fail clearly if gradlew not runnable
  if ! ./gradlew --version >/dev/null 2>&1; then
    echo "ERROR: ./gradlew exists but failed to run. Ensure wrapper is valid and Gradle 7.6-compatible." >&2
    exit 4
  fi
fi
# Completed
