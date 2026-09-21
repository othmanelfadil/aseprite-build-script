#!/usr/bin/env bash

log_info() { printf '%s\n' "$*" >&2;}
log_ok() { printf '%s\n' "$*" >&2;}
log_warn() { printf 'warning: %s\n' "$*" >&2;}
log_error() { printf 'error: %s\n' "$*" >&2;}
log_step() { printf '%s\n' "$*" >&2;}

die() {
    log_error "$*"
    exit 1
}