#!/bin/zsh

set -u

readonly USER_HOME="${HOME:-}"
if [[ -z "${USER_HOME}" ]]; then
    print -u2 -- "The current user home directory could not be determined."
    exit 1
fi

readonly STATE_DIRECTORY="${DSH_LAUNCHER_STATE_DIR:-${USER_HOME}/Library/Application Support/DSH Launcher}"
readonly PID_FILE="${STATE_DIRECTORY}/server.pid"
readonly PORT_FILE="${STATE_DIRECTORY}/server.port"

if [[ ! -f "${PID_FILE}" ]]; then
    print -r -- "No launcher-managed DSH backend is recorded."
    exit 0
fi

pid="$(<"${PID_FILE}")"
if [[ "${pid}" != <-> ]] || ! /bin/kill -0 "${pid}" 2>/dev/null; then
    print -r -- "The recorded backend is no longer running."
elif ! /bin/ps -p "${pid}" -o command= 2>/dev/null | /usr/bin/grep -Eq '(@deepseek-ai/dsh|[/ ]dsh([/ ]|$)).*web'; then
    print -u2 -- "Refusing to stop PID ${pid}: it is not a verified DSH Web process."
    exit 1
else
    /bin/kill "${pid}"
    for attempt in {1..20}; do
        /bin/kill -0 "${pid}" 2>/dev/null || break
        /bin/sleep 0.25
    done
    print -r -- "Stopped DSH backend PID ${pid}."
fi

[[ -e "${PID_FILE}" ]] && /usr/bin/unlink "${PID_FILE}"
[[ -e "${PORT_FILE}" ]] && /usr/bin/unlink "${PORT_FILE}"
