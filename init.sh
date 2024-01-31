#!/usr/bin/env sh

set -e

VERSION=0.1.0
PROJECT_NAME=gdevops
INSTALL_DIR="$HOME/.$PROJECT_NAME"
ACME_SH_EXEC="/root/.acme.sh/acme.sh"

if [ -f "$INSTALL_DIR/getoptions.sh" ]; then
    . "$INSTALL_DIR/getoptions.sh"
else
    . ./getoptions.sh
fi

parser_definition() {
	setup   REST help:usage abbr:true -- \
		"Usage: ${2##*/} [global options...] [command] [options...] [arguments...]"
	msg -- '' 'gdevops setup_ssl_certs' ''
	msg -- 'Options:'
	disp    :usage  -h --help
	disp    VERSION    --version

	msg -- '' 'Commands:'
	cmd install -- "Installs gdevops"
	cmd test -- "Tests connectivity and tools to run setup scripts."
	cmd setup_ssl_certs -- "Issue and install ssl certs using acme.sh"
}

parser_definition_install() {
	setup   REST help:usage abbr:true -- \
		"Usage: ${2##*/} install [options...] [arguments...]"
	msg -- '' 'gdevops install' ''
	msg -- 'Options:'
	disp    :usage  -h --help
}

parser_definition_test() {
	setup   REST help:usage abbr:true -- \
		"Usage: ${2##*/} test [options...] [arguments...]"
	msg -- '' 'gdevops test' ''
	msg -- 'Options:'
	option  INFISICAL_ENV  -e --infisical-env on:"prod"  -- "environment name for infisical"
	disp    :usage  -h --help
}

parser_definition_setup_ssl_certs() {
	setup   REST help:usage abbr:true -- \
		"Usage: ${2##*/} setup_ssl_certs [options...] [arguments...]"
	msg -- '' 'gdevops setup_ssl_certs' ''
	msg -- 'Options:'
	option  INFISICAL_ENV  -e --infisical-env on:"prod"  -- "environment name for infisical"
	disp    :usage  -h --help
}

eval "$(getoptions parser_definition parse "$0") exit 1"
parse "$@"
eval "set -- $REST"

if [ $# -gt 0 ]; then
	cmd=$1
	shift
	case $cmd in
	    install)
			eval "$(getoptions parser_definition_install parse "$0")"
			parse "$@"
			eval "set -- $REST"
			;;
        test)
            eval "$(getoptions parser_definition_test parse "$0")"
            parse "$@"
            eval "set -- $REST"
            ;;
		setup_ssl_certs)
			eval "$(getoptions parser_definition_setup_ssl_certs parse "$0")"
			parse "$@"
			eval "set -- $REST"
			;;
		--) # no subcommand, arguments only
	esac
else
    cmd=""
fi

if [ -f "$INSTALL_DIR/lib/base.sh" ]; then
    . "$INSTALL_DIR/lib/base.sh"
else
    . ./lib/base.sh
fi

install() {
    _info "installing $PROJECT_NAME"

    if [ ! -d "$INSTALL_DIR" ]; then
        if ! mkdir -p "$INSTALL_DIR"; then
            _err "failed to create installation directory."
        fi

        chmod 700 "$INSTALL_DIR"
    fi

    cp -R ./* "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/init.sh"

    if [ "$?" != "0" ]; then
        _err "installation failed. couldn't copy the package."
    fi

    _profile="$(_detect_profile)"
    if [ "$_profile" ]; then
        _info "found shell profile: $_profile"
        _info "creating alias $PROJECT_NAME in '$_profile' profile"
        _setopt "$_profile" "alias $PROJECT_NAME" "=" "\"$INSTALL_DIR/init.sh\""
    else
        _info "no shell profile is found, you will need to go into $INSTALL_DIR to use $PROJECT_NAME"
    fi

    _success "gdevops installed successfully"
}

set_env() {
    infisical export --env=$INFISICAL_ENV --format=dotenv-export > "$PWD/gdevops.env"
    . "$PWD/gdevops.env"
    rm "$PWD/gdevops.env"
}

test() {
    # validate dependencies
    if ! _exists nginx; then _err "nginx not found."; fi
    if ! _exists $ACME_SH_EXEC; then _err "acme.sh not found."; fi
    if ! _exists psl; then _err "psl not found."; fi

    echo "acme.sh version: $($ACME_SH_EXEC --version)"
    echo "nginx version: $(nginx -v)"

    # validate env vars
    if [ -z "$GDEVOPS_APP_HOSTNAME" ]; then _err "missing env var: GDEVOPS_APP_HOSTNAME"; fi
    if [ -z "$GDEVOPS_SSL_CERTS_ROOT" ]; then _err "missing env var: GDEVOPS_SSL_CERTS_ROOT"; fi
    if [ -z "$GDEVOPS_APP_DNS_PROVIDER" ]; then _err "missing env var: GDEVOPS_APP_DNS_PROVIDER"; fi

    _success "all tests pass for $GDEVOPS_APP_HOSTNAME"
}

setup_ssl_certs() {
    # validate dependencies
    if ! _exists nginx; then _err "nginx not found."; fi
    if ! _exists $ACME_SH_EXEC; then _err "acme.sh not found."; fi
    if ! _exists psl; then _err "psl not found."; fi

    # validate env vars
    if [ -z "$GDEVOPS_APP_HOSTNAME" ]; then _err "missing env var: GDEVOPS_APP_HOSTNAME"; fi
    if [ -z "$GDEVOPS_SSL_CERTS_ROOT" ]; then _err "missing env var: GDEVOPS_SSL_CERTS_ROOT"; fi
    if [ -z "$GDEVOPS_APP_DNS_PROVIDER" ]; then _err "missing env var: GDEVOPS_APP_DNS_PROVIDER"; fi

    # validate dns provider env vars
    if [ "$GDEVOPS_APP_DNS_PROVIDER" = "gandi" ]; then
        if [ -z "$GANDI_LIVEDNS_KEY" ]; then _err "missing env var: GANDI_LIVEDNS_KEY"; fi
    elif [ "$GDEVOPS_APP_DNS_PROVIDER" = "cloudflare" ]; then
        if [ -z "$CF_Key" ]; then _err "missing env var: CF_Key"; fi
        if [ -z "$CF_Email" ]; then _err "missing env var: CF_Email"; fi
    else
        _err "missing or invalid dns provider."
    fi

    _info "installing ssl certs for $GDEVOPS_APP_HOSTNAME..."

    # prepare cmd args for acme.sh
    acme_arg_dns=""
    if [ "$GDEVOPS_APP_DNS_PROVIDER" = "gandi" ]; then
        acme_arg_dns="--dns dns_gandi_livedns"
    elif [ "$GDEVOPS_APP_DNS_PROVIDER" = "cloudflare" ]; then
        acme_arg_dns="--dns dns_cf"
    else
        _err "missing or invalid dns provider."
    fi

    acme_arg_hostnames="-d $GDEVOPS_APP_HOSTNAME"
    if ! is_subdomain "$GDEVOPS_APP_HOSTNAME"; then
      acme_arg_hostnames="${acme_arg_hostnames} -d www.$GDEVOPS_APP_HOSTNAME"
    fi

    # obtain ssl certs
    $ACME_SH_EXEC --issue $acme_arg_hostnames $acme_arg_dns

    # create a directory to keep ssl certs permanently
    mkdir -p "${GDEVOPS_SSL_CERTS_ROOT}$GDEVOPS_APP_HOSTNAME"
    ssl_cert=${GDEVOPS_SSL_CERTS_ROOT}$GDEVOPS_APP_HOSTNAME/fullchain.pem
    ssl_cert_key=${GDEVOPS_SSL_CERTS_ROOT}$GDEVOPS_APP_HOSTNAME/key.pem

    # copy cert files to the directory and configure cert auto-renewal
    $ACME_SH_EXEC --install-cert -d "$GDEVOPS_APP_HOSTNAME" \
        --key-file "$ssl_cert_key" \
        --fullchain-file "$ssl_cert" \
        --reloadcmd "service nginx force-reload"

    _success "ssl certs are installed successfully for $GDEVOPS_APP_HOSTNAME"
}

subcommand=$cmd
is_env_exist=no
if [ ! -z "$GDEVOPS_APP_HOSTNAME" ]; then
    is_env_exist=yes
fi

if ! _exists infisical; then _err "infisical not found."; fi

if [ -z $INFISICAL_ENV ]; then
    INFISICAL_ENV=prod
fi

case $subcommand in
    install)
        install
        ;;
    test)
        if [ "$is_env_exist" = "yes" ]; then
            test
        else
            set_env
            ssh $GDEVOPS_SSH_CONN_URI 'bash -lci "gdevops test"'
        fi
        ;;
    setup_ssl_certs)
        if [ "$is_env_exist" = "yes" ]; then
            setup_ssl_certs
        else
            set_env
            ssh $GDEVOPS_SSH_CONN_URI 'bash -lci "gdevops setup_ssl_certs"'
        fi
        ;;
    *)
        _err "no subcommand specified."
esac
