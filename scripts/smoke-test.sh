#!/bin/zsh

set -euo pipefail

readonly ROOT_DIRECTORY="${0:A:h:h}"
readonly APP_EXECUTABLE="${ROOT_DIRECTORY}/dist/DSH Launcher.app/Contents/MacOS/DSHLauncher"

if [[ ! -x "${APP_EXECUTABLE}" ]]; then
    print -u2 -- "Build the app first with ./scripts/build.sh"
    exit 1
fi

dsh_executable="${DSH_BIN:-$(command -v dsh 2>/dev/null || true)}"
if [[ -z "${dsh_executable}" || ! -x "${dsh_executable}" ]]; then
    print -u2 -- "A working dsh executable is required for the smoke test."
    exit 1
fi

test_root="$(/usr/bin/mktemp -d /tmp/dsh-launcher-smoke.XXXXXX)"
cleanup() {
    DSH_LAUNCHER_STATE_DIR="${test_root}/state" "${ROOT_DIRECTORY}/src/stop-backend.zsh" >/dev/null 2>&1 || true
    if [[ "${test_root}" == /tmp/dsh-launcher-smoke.* && -d "${test_root}" ]]; then
        /bin/rm -R "${test_root}"
    fi
}
trap cleanup EXIT

selected_port=""
for candidate in {39180..39200}; do
    if [[ -z "$(/usr/sbin/lsof -tiTCP:"${candidate}" -sTCP:LISTEN 2>/dev/null | /usr/bin/head -n 1)" ]]; then
        selected_port="${candidate}"
        break
    fi
done
if [[ -z "${selected_port}" ]]; then
    print -u2 -- "No free smoke-test port was found."
    exit 1
fi

DSH_BIN="${dsh_executable}" \
DSH_PORT="${selected_port}" \
DSH_LAUNCHER_NO_OPEN=1 \
DSH_LAUNCHER_ISOLATED=1 \
DSH_LAUNCHER_STATE_DIR="${test_root}/state" \
DSH_LAUNCHER_LOG_DIR="${test_root}/logs" \
"${APP_EXECUTABLE}"

/usr/bin/curl --fail --silent --max-time 2 "http://127.0.0.1:${selected_port}/" >/dev/null
print -r -- "Smoke test passed: HTTP 200 on 127.0.0.1:${selected_port}"
