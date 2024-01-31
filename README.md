# gdevops
CLI tool to manage app servers based on shell, letsencrypt, nginx and infisical.

## Install
```sh
git clone https://${GITHUB_TOKEN}@github.com/muratgozel/gdevops.git
cd gdevops
./init.sh install
```

## Use
```sh
# test env vars and tools required to run scripts
gdevops test

# install ssl certs
gdevops setup_ssl_certs

# install nginx host
gdevops setup_proxy_host
```

## Development
```sh
# in case of missing/outdated getoptions.sh, generate argument parser:
./packages/gengetoptions library > getoptions.sh
```
