#!/usr/bin/env sh

. "$INSTALL_DIR/lib/colored_print.sh"

_err() {
    __red "[$(date -u)] $1"
    printf "\n" >&2

    exit 1
}

_info() {
    __blue "[$(date -u)] $1"
    printf "\n" >&2
}

_success() {
    __green "[$(date -u)] $1"
    printf "\n" >&2
}

_exists() {
    cmd="$1"

    if [ -z "$cmd" ]; then
        __red "Usage: _exists cmd" >&2 && printf "\n" >&2
        return 1
    fi

    if eval type type >/dev/null 2>&1; then
        eval type "$cmd" >/dev/null 2>&1
    elif command >/dev/null 2>&1; then
        command -v "$cmd" >/dev/null 2>&1
    else
        which "$cmd" >/dev/null 2>&1
    fi

    ret="$?"

    return $ret
}

is_subdomain() {
    output=$(psl --print-unreg-domain $1)
    domain=${output%%: *}
    suffix=${output##*: }
    name=${domain%%.$suffix}
    dots_count=$(echo $name | tr -cd '.' | wc -c | tr -d ' ')

    [ "$dots_count" -gt 0 ]
}

is_nginx_config_valid() {
  nginx -t 2>/dev/null > /dev/null
}

_detect_profile() {
    if [ -n "$PROFILE" -a -f "$PROFILE" ]; then
        echo "$PROFILE"
        return
    fi

    DETECTED_PROFILE=''
    SHELLTYPE="$(basename "/$SHELL")"

    if [ "$SHELLTYPE" = "bash" ]; then
        if [ -f "$HOME/.bashrc" ]; then
            DETECTED_PROFILE="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            DETECTED_PROFILE="$HOME/.bash_profile"
        fi
    elif [ "$SHELLTYPE" = "zsh" ]; then
        DETECTED_PROFILE="$HOME/.zshrc"
    fi

    if [ -z "$DETECTED_PROFILE" ]; then
        if [ -f "$HOME/.profile" ]; then
            DETECTED_PROFILE="$HOME/.profile"
        elif [ -f "$HOME/.bashrc" ]; then
            DETECTED_PROFILE="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            DETECTED_PROFILE="$HOME/.bash_profile"
        elif [ -f "$HOME/.zshrc" ]; then
            DETECTED_PROFILE="$HOME/.zshrc"
        fi
    fi

    echo "$DETECTED_PROFILE"
}

_contains() {
    _str="$1"
    _sub="$2"
    echo "$_str" | grep -- "$_sub" >/dev/null 2>&1
}

_setopt() {
    __conf="$1"
    __opt="$2"
    __sep="$3"
    __val="$4"
    __end="$5"

    if [ -z "$__opt" ]; then
        _info 'usage: _setopt "file"  "opt"  "="  "value" [";"]'
        return
    fi
    if [ ! -f "$__conf" ]; then
        touch "$__conf"
    fi

    if grep -n "^$__opt$__sep" "$__conf" >/dev/null; then
      if _contains "$__val" "&"; then
        __val="$(echo "$__val" | sed 's/&/\\&/g')"
      fi
      if _contains "$__val" "|"; then
        __val="$(echo "$__val" | sed 's/|/\\|/g')"
      fi
      text="$(cat "$__conf")"
      printf -- "%s\n" "$text" | sed "s|^$__opt$__sep.*$|$__opt$__sep$__val$__end|" >"$__conf"

    elif grep -n "^#$__opt$__sep" "$__conf" >/dev/null; then
      if _contains "$__val" "&"; then
        __val="$(echo "$__val" | sed 's/&/\\&/g')"
      fi
      if _contains "$__val" "|"; then
        __val="$(echo "$__val" | sed 's/|/\\|/g')"
      fi
      text="$(cat "$__conf")"
      printf -- "%s\n" "$text" | sed "s|^#$__opt$__sep.*$|$__opt$__sep$__val$__end|" >"$__conf"

    else
      echo "$__opt$__sep$__val$__end" >>"$__conf"
    fi
}
