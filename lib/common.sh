#!/usr/bin/env bash

if [[ -n "${_ASEPRITE_INSTALLER_COMMON_SH}" ]]; then
    return 0
fi
_ASEPRITE_INSTALLER_COMMON_SH=1

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RED=$'\033[0;31m'
    C_GREEN=$'\033[0;32m'
    C_YELLOW=$']033[0;33m'
    C_BOLD=$'033[1m'
    C_RESET=$'033[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BOLD=""; C_RESET=""
fi

log_info()  { printf '%s\n' "$*" >&2;}
log_ok()    { printf '%s%s%s\n' "$C_GREEN" "$*" "$C_RESET" >&2;}
log_warn()  { printf '%swarning:%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2;}
log_error() { printf '%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2;}
log_step()  { printf '%s%s%s\n' "$C_BOLD" "$*" "$C_RESET" >&2;}

die() {
    log_error "$*"
    exit 1
}

_on_err(){
    local exit_code=$?
    local line_no=$1
    local src="${BASH_SOURCE[1]:-$0}"
    log_error "failed at ${src}:${line_no} (exit code ${exit_code})"
    log_error "see README.md troubleshooting"
    exit "$exit_code"
}

install_error_trap(){
    trap '_on_err $LINENO' ERR
}

confirm() {
    local prompt="$1"
    if [[ "${ASSUME_YES:-0}" == "1" ]]; then
        return 0
    fi
    local reply 
    read -r -p "$prompt [y/n] " reply </dev/ty || reply=""
    [[ "$reply" =~ ^[Yy]$ ]]
}

has_cmd() {command -v "$1" >/dev/null 2>&1;} 

run() {
    log_info "$*"
    "$@"
}

run_sudo() {
    if  [[ "$(id -u)" == "0"]]; then\
        run "$@"
    else 
        log_info "sudo $*"
        sudo "$@"
    fi 
}

version_ge() {
    local a="${1#v}" b="${2#v}"
    [[ "$a" == "$b" ]] && return 0
    local highest
    highest=$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -n1)
    [[  "$highest" == "$a" ]]
}

free_space() {
    local path="$1"
    df -Pk "$path" 2>/dev/null | awk 'NR==2 {printf "%d", $4/1024/1024 }'
}

run_ninja_with_bar() {
    if [[ ! -t 1 ]]; then
        ninja "$@"
        return $?
    fi

    local status=0
    NINJA_STATUS=$'@@P %f %t\n' ninja "$@" 2>&1 | awk -v CR=$'\r' '
        /^@@P / {
            cur = $2 + 0; tot = $3 + 0;
            pct = (tot > 0) ? int(cur * 100 / tot) : 0;
            width = 32;
            filled = (tot > 0) ? int(width * cur / tot) : 0;
            bar = "";
            for (i = 0; i < width; i++) bar = bar (i < filled ? "#" : "-");
            printf "%s[%s] %3d%% (%d/%d)", CR, bar, pct, cur, tot;
            fflush();
            next;
        }
        { printf "%s%s\n", CR, $0; fflush(); }
        END { printf "\n"; }
    '
    status="${PIPESTATUS[0]}"
    return "$status"
}

LOG_FILE=""
init_log_file() {
    LOG_FILE="$1"
    mkdir -p "$(dirname "$LOG_FILE")"
    : > "$LOG_FILE"
}

run_logged() {
    if [[ "${VERBOSE:-0}" == "1" || -z "$LOG_FILE" ]]; then
        run "$@"
        return $?
    fi
    log_info "$*"
    {
        echo "+ $*"
        "$@"
    } >>"$LOG_FILE" 2>&1
}

tail_log() {
    if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
        log_error "last lines of $LOG_FILE:"
        tail -n 25 "$LOG_FILE" >&2
    fi
}