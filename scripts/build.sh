#!/bin/zsh

set -euo pipefail

readonly ROOT_DIRECTORY="${0:A:h:h}"
readonly DIST_DIRECTORY="${ROOT_DIRECTORY}/dist"
readonly APP_BUNDLE="${DIST_DIRECTORY}/DSH Launcher.app"
readonly VERSION="$(<"${ROOT_DIRECTORY}/VERSION")"

if [[ -e "${APP_BUNDLE}" ]]; then
    print -u2 -- "Build output already exists: ${APP_BUNDLE}"
    print -u2 -- "Move or delete it before rebuilding."
    exit 1
fi

work_directory="$(/usr/bin/mktemp -d /tmp/dsh-launcher-build.XXXXXX)"
cleanup() {
    if [[ "${work_directory}" == /tmp/dsh-launcher-build.* && -d "${work_directory}" ]]; then
        /bin/rm -R "${work_directory}"
    fi
}
trap cleanup EXIT

readonly TEMP_APP="${work_directory}/DSH Launcher.app"
readonly ICONSET_DIRECTORY="${work_directory}/DSHLauncher.iconset"

/bin/mkdir -p "${TEMP_APP}/Contents/MacOS" "${TEMP_APP}/Contents/Resources" "${ICONSET_DIRECTORY}" "${DIST_DIRECTORY}"
/bin/cp "${ROOT_DIRECTORY}/packaging/Info.plist" "${TEMP_APP}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${TEMP_APP}/Contents/Info.plist"
/bin/cp "${ROOT_DIRECTORY}/src/launcher.zsh" "${TEMP_APP}/Contents/MacOS/DSHLauncher"
/bin/cp "${ROOT_DIRECTORY}/src/stop-backend.zsh" "${TEMP_APP}/Contents/Resources/stop-backend.zsh"
/bin/chmod 755 "${TEMP_APP}/Contents/MacOS/DSHLauncher" "${TEMP_APP}/Contents/Resources/stop-backend.zsh"

readonly ICON_SOURCE="${ROOT_DIRECTORY}/assets/launcher-icon.png"
/usr/bin/sips -z 16 16 "${ICON_SOURCE}" --out "${ICONSET_DIRECTORY}/icon_16x16.png" >/dev/null
/usr/bin/sips -z 32 32 "${ICON_SOURCE}" --out "${ICONSET_DIRECTORY}/icon_16x16@2x.png" >/dev/null
/usr/bin/sips -z 32 32 "${ICON_SOURCE}" --out "${ICONSET_DIRECTORY}/icon_32x32.png" >/dev/null
/usr/bin/sips -z 64 64 "${ICON_SOURCE}" --out "${ICONSET_DIRECTORY}/icon_32x32@2x.png" >/dev/null
/usr/bin/sips -z 128 128 "${ICON_SOURCE}" --out "${ICONSET_DIRECTORY}/icon_128x128.png" >/dev/null
/usr/bin/sips -z 256 256 "${ICON_SOURCE}" --out "${ICONSET_DIRECTORY}/icon_128x128@2x.png" >/dev/null
/usr/bin/sips -z 256 256 "${ICON_SOURCE}" --out "${ICONSET_DIRECTORY}/icon_256x256.png" >/dev/null
/usr/bin/sips -z 512 512 "${ICON_SOURCE}" --out "${ICONSET_DIRECTORY}/icon_256x256@2x.png" >/dev/null
/usr/bin/sips -z 512 512 "${ICON_SOURCE}" --out "${ICONSET_DIRECTORY}/icon_512x512.png" >/dev/null
/usr/bin/sips -z 1024 1024 "${ICON_SOURCE}" --out "${ICONSET_DIRECTORY}/icon_512x512@2x.png" >/dev/null
/usr/bin/iconutil -c icns "${ICONSET_DIRECTORY}" -o "${TEMP_APP}/Contents/Resources/DSHLauncher.icns"

/usr/bin/xattr -cr "${TEMP_APP}"
/usr/bin/codesign --force --deep --sign - "${TEMP_APP}"
/usr/bin/codesign --verify --deep --strict "${TEMP_APP}"
/bin/mv "${TEMP_APP}" "${APP_BUNDLE}"

print -r -- "Built ${APP_BUNDLE}"
