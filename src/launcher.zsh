#!/bin/zsh

set -u

readonly APP_TITLE="DSH Launcher"
readonly UPSTREAM_URL="https://github.com/deepseek-ai/deepseek-harness"
readonly LOOPBACK_HOST="127.0.0.1"
readonly USER_HOME="${HOME:-}"
readonly NO_OPEN="${DSH_LAUNCHER_NO_OPEN:-0}"
readonly ISOLATED_MODE="${DSH_LAUNCHER_ISOLATED:-0}"

show_error() {
    /usr/bin/osascript - "$1" <<'APPLESCRIPT'
on run argv
    display dialog (item 1 of argv) with title "DSH Launcher" buttons {"OK"} default button "OK" with icon stop
end run
APPLESCRIPT
}

show_missing_backend() {
    local answer
    answer="$(/usr/bin/osascript - "${UPSTREAM_URL}" <<'APPLESCRIPT'
on run argv
    set resultButton to button returned of (display dialog "A persistent dsh executable was not found. Install DeepSeek Harness first, then reopen DSH Launcher." with title "DSH Launcher" buttons {"Cancel", "Open upstream instructions"} default button "Open upstream instructions" with icon caution)
    return resultButton
end run
APPLESCRIPT
)"
    if [[ "${answer}" == "Open upstream instructions" ]]; then
        /usr/bin/open "${UPSTREAM_URL}"
    fi
}

if [[ -z "${USER_HOME}" ]]; then
    show_error "The current user home directory could not be determined."
    exit 1
fi

export PATH="${USER_HOME}/.local/bin:${USER_HOME}/Library/pnpm:${USER_HOME}/.local/share/pnpm:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
export LANG="${LANG:-en_US.UTF-8}"

readonly LOG_DIRECTORY="${DSH_LAUNCHER_LOG_DIR:-${USER_HOME}/Library/Logs/DSH Launcher}"
readonly STATE_DIRECTORY="${DSH_LAUNCHER_STATE_DIR:-${USER_HOME}/Library/Application Support/DSH Launcher}"
readonly LOG_FILE="${LOG_DIRECTORY}/server.log"
readonly PID_FILE="${STATE_DIRECTORY}/server.pid"
readonly PORT_FILE="${STATE_DIRECTORY}/server.port"

resolve_dsh() {
    local discovered
    discovered="$(command -v dsh 2>/dev/null || true)"

    local -a candidates
    candidates=(
        "${DSH_BIN:-}"
        "${discovered}"
        "${USER_HOME}/.local/bin/dsh"
        "${USER_HOME}/Library/pnpm/dsh"
        "${USER_HOME}/.local/share/pnpm/dsh"
        "/opt/homebrew/bin/dsh"
        "/usr/local/bin/dsh"
    )

    local candidate
    for candidate in "${candidates[@]}"; do
        if [[ -n "${candidate}" && -x "${candidate}" ]]; then
            print -r -- "${candidate}"
            return 0
        fi
    done
    return 1
}

valid_port() {
    [[ "$1" == <-> ]] && (( $1 >= 1 && $1 <= 65535 ))
}

listener_pid() {
    /usr/sbin/lsof -tiTCP:"$1" -sTCP:LISTEN 2>/dev/null | /usr/bin/head -n 1
}

is_dsh_pid() {
    local pid="$1"
    [[ "${pid}" == <-> ]] || return 1
    /bin/kill -0 "${pid}" 2>/dev/null || return 1
    /bin/ps -p "${pid}" -o command= 2>/dev/null | /usr/bin/grep -Eq '(@deepseek-ai/dsh|[/ ]dsh([/ ]|$)).*web'
}

http_ready() {
    /usr/bin/curl --fail --silent --max-time 1 "http://${LOOPBACK_HOST}:$1/" >/dev/null 2>&1
}

open_web_ui() {
    if [[ "${NO_OPEN}" != "1" ]]; then
        /usr/bin/open "http://${LOOPBACK_HOST}:$1/"
    fi
}

record_state() {
    print -r -- "$1" > "${PID_FILE}"
    print -r -- "$2" > "${PORT_FILE}"
}

read_recorded_pid() {
    [[ -f "${PID_FILE}" ]] || return 1
    local pid
    pid="$(<"${PID_FILE}")"
    is_dsh_pid "${pid}" || return 1
    print -r -- "${pid}"
}

read_recorded_port() {
    [[ -f "${PORT_FILE}" ]] || return 1
    local port
    port="$(<"${PORT_FILE}")"
    valid_port "${port}" || return 1
    print -r -- "${port}"
}

choose_free_port() {
    local preferred="${DSH_PORT:-3080}"
    if ! valid_port "${preferred}"; then
        preferred=3080
    fi

    local -a candidates
    candidates=("${preferred}" {3080..3090})

    local candidate
    local seen=" "
    for candidate in "${candidates[@]}"; do
        if [[ "${seen}" == *" ${candidate} "* ]]; then
            continue
        fi
        seen+="${candidate} "
        if [[ -z "$(listener_pid "${candidate}")" ]]; then
            print -r -- "${candidate}"
            return 0
        fi
    done
    return 1
}

launch_command_for() {
    local dsh_executable="$1"
    local node_executable
    node_executable="$(command -v node 2>/dev/null || true)"

    if [[ "$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null || print 0)" == "1" && -n "${node_executable}" ]]; then
        if /usr/bin/file "${node_executable}" 2>/dev/null | /usr/bin/grep -q 'arm64'; then
            print -r -- "/usr/bin/arch"
            print -r -- "-arm64"
        fi
    fi
    print -r -- "${dsh_executable}"
}

/bin/mkdir -p "${LOG_DIRECTORY}" "${STATE_DIRECTORY}"

recorded_pid="$(read_recorded_pid 2>/dev/null || true)"
recorded_port="$(read_recorded_port 2>/dev/null || true)"
if [[ -n "${recorded_pid}" && -n "${recorded_port}" && -n "$(listener_pid "${recorded_port}")" ]]; then
    if http_ready "${recorded_port}"; then
        open_web_ui "${recorded_port}"
        exit 0
    fi
fi

if [[ "${ISOLATED_MODE}" != "1" ]]; then
    for candidate_port in {3080..3090}; do
        candidate_pid="$(listener_pid "${candidate_port}")"
        if [[ -n "${candidate_pid}" ]] && is_dsh_pid "${candidate_pid}" && http_ready "${candidate_port}"; then
            record_state "${candidate_pid}" "${candidate_port}"
            open_web_ui "${candidate_port}"
            exit 0
        fi
    done
fi

dsh_executable="$(resolve_dsh 2>/dev/null || true)"
if [[ -z "${dsh_executable}" ]]; then
    show_missing_backend
    exit 1
fi

selected_port="$(choose_free_port 2>/dev/null || true)"
if [[ -z "${selected_port}" ]]; then
    show_error "No free loopback port was found between 3080 and 3090."
    exit 1
fi

local_launch_lines="$(launch_command_for "${dsh_executable}")"
typeset -a launch_command
launch_command=("${(@f)local_launch_lines}")

{
    print -r -- ""
    print -r -- "[$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')] Starting DSH on ${LOOPBACK_HOST}:${selected_port}"
} >> "${LOG_FILE}"

/usr/bin/nohup "${launch_command[@]}" web --no-open --host "${LOOPBACK_HOST}" --port "${selected_port}" >> "${LOG_FILE}" 2>&1 < /dev/null &
backend_pid=$!
record_state "${backend_pid}" "${selected_port}"

for attempt in {1..60}; do
    if http_ready "${selected_port}"; then
        open_web_ui "${selected_port}"
        exit 0
    fi

    if ! /bin/kill -0 "${backend_pid}" 2>/dev/null; then
        recent_log="$(/usr/bin/tail -n 12 "${LOG_FILE}" 2>/dev/null)"
        show_error "The DSH backend failed to start.\n\n${recent_log}\n\nLog: ${LOG_FILE}"
        exit 1
    fi
    /bin/sleep 0.5
done

show_error "The DSH backend did not become ready within 30 seconds.\n\nLog: ${LOG_FILE}"
exit 1
