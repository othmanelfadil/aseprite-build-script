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