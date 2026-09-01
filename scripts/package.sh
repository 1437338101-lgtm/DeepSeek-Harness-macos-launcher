#!/bin/zsh

set -euo pipefail

readonly ROOT_DIRECTORY="${0:A:h:h}"
readonly DIST_DIRECTORY="${ROOT_DIRECTORY}/dist"
readonly APP_BUNDLE="${DIST_DIRECTORY}/DSH Launcher.app"
readonly VERSION="$(<"${ROOT_DIRECTORY}/VERSION")"
readonly ARCHIVE_NAME="DSH-Launcher-macOS-universal-v${VERSION}.zip"
readonly ARCHIVE_PATH="${DIST_DIRECTORY}/${ARCHIVE_NAME}"
readonly CHECKSUM_PATH="${DIST_DIRECTORY}/SHA256SUMS"

if [[ ! -d "${APP_BUNDLE}" ]]; then
    "${ROOT_DIRECTORY}/scripts/build.sh"
fi

if [[ -e "${ARCHIVE_PATH}" || -e "${CHECKSUM_PATH}" ]]; then
    print -u2 -- "Release output already exists in ${DIST_DIRECTORY}."
    print -u2 -- "Move or delete the existing ZIP and checksum before rebuilding."
    exit 1
fi

COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --keepParent "${APP_BUNDLE}" "${ARCHIVE_PATH}"
(
    cd "${DIST_DIRECTORY}"
    /usr/bin/shasum -a 256 "${ARCHIVE_NAME}" > "${CHECKSUM_PATH}"
)

print -r -- "Packaged ${ARCHIVE_PATH}"
print -r -- "Checksums ${CHECKSUM_PATH}"
