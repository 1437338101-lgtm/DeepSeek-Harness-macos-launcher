#!/bin/zsh

set -euo pipefail

readonly ROOT_DIRECTORY="${0:A:h:h}"
privacy_status=0

scan_text() {
    local label="$1"
    local pattern="$2"
    shift 2
    local matches
    matches="$(/usr/bin/grep -RInE --exclude-dir=.git --exclude-dir=dist --exclude='*.icns' --exclude='*.png' -- "${pattern}" "$@" 2>/dev/null || true)"
    if [[ -n "${matches}" ]]; then
        print -u2 -- "Privacy check failed (${label}):"
        print -u2 -- "${matches}"
        privacy_status=1
    fi
}

scan_text "absolute macOS user path" '/Users/[A-Za-z0-9._-]+' "${ROOT_DIRECTORY}"
scan_text "credential-like value" '(API_KEY|AUTH_TOKEN|PASSWORD|SECRET)[[:space:]]*=[[:space:]]*[^$<[:space:]]+' "${ROOT_DIRECTORY}"
scan_text "private key" 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' "${ROOT_DIRECTORY}"

if [[ -d "${ROOT_DIRECTORY}/dist/DSH Launcher.app" ]]; then
    binary_matches="$(/usr/bin/strings "${ROOT_DIRECTORY}/dist/DSH Launcher.app/Contents/MacOS/DSHLauncher" | /usr/bin/grep -E '/Users/[A-Za-z0-9._-]+' || true)"
    if [[ -n "${binary_matches}" ]]; then
        print -u2 -- "Privacy check failed (built launcher contains a user path)."
        privacy_status=1
    fi
fi

if (( privacy_status != 0 )); then
    exit 1
fi
print -r -- "Privacy check passed."
