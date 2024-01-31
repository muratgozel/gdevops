#!/usr/bin/env sh

__green() {
    if [ "${SS_NO_COLOR:-0}" = "1" ]; then
        printf -- "%b" "$1"
        return
    fi

    printf '\33[1;32m%b\33[0m' "$1"
}

__red() {
    if [ "${SS_NO_COLOR:-0}" = "1" ]; then
        printf -- "%b" "$1"
        return
    fi

    printf '\33[1;31m%b\33[0m' "$1"
}

__blue() {
    if [ "${SS_NO_COLOR:-0}" = "1" ]; then
        printf -- "%b" "$1"
        return
    fi

    printf '\33[1;34m%b\33[0m' "$1"
}
