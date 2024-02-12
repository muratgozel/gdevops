# gdevops
CLI tool to manage app servers based on shell, acme.sh, nginx and infisical.

## How it works
It sends your command to the server through ssh and executes it. All the env vars required for the command to run, set on the local machine and sent to the server on execution.

## Setup
### Install required software and tools
Install nginx, psl and acme.sh in server and infisical cli in both local and server environments.

### Configure environment variable transfer
1. Add `SendEnv GDEVOPS_*` to your host in your ssh config in local machine.
2. Add `AcceptEnv LANG LC_* GDEVOPS_*` to your `sshd_config` in server.
3. Persist the following env vars in server's shell profile:
```sh
export GDEVOPS_APPS_ROOT=[PATH]
export GDEVOPS_SSL_CERTS_ROOT=[PATH]
export GDEVOPS_APP_ROOT_GROUP=[GROUP_OWNER]
export GANDI_LIVEDNS_KEY=[ACME.SH MAY USE THIS]
export CF_Key=[ACME.SH MAY USE THIS]
export CF_Email=[ACME.SH MAY USE THIS]
export GITHUB_TOKEN=[TOKEN]
export INFISICAL_API_URL=[URL]
```

### Install gdevops
In both local and server:
```sh
git clone https://github.com/muratgozel/gdevops.git
cd gdevops
./init.sh install
```
It installs itself to the user's home dir, under `.gdevops`

### Create a project
Create a project in infisical and set the following environment variables as they are necessary to run the gdevops commands:
```sh
GDEVOPS_APP_DNS_PROVIDER=cloudflare or gandi
GDEVOPS_APP_HOSTNAME=domain.tld
GDEVOPS_APP_PORT=app port for nginx proxy it, leave empty if not available
GDEVOPS_SSH_CONN_URI=ssh connection uri
```
In local machine, run `infisical init`.

You are ready to run commands.

## Use
Always test first. Run `gdevops --help` to see the available commands.
```sh
# test env vars and tools required to run scripts
gdevops test

# install ssl certs
gdevops setup_ssl_certs

# install nginx host
gdevops setup_proxy_host
# it will pick the proper nginx config host according to your configuration but
# if you want to use custom nginx config name it same as your $GDEVOPS_APP_HOSTNAME.conf and
# place it to where you execute the command, project root usually.

gdevops remove_ssl_certs
gdevops remove_proxy_host
```

## Development
```sh
# in case of missing/outdated getoptions.sh, generate argument parser:
./packages/gengetoptions library > getoptions.sh
```
