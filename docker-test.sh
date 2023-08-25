#!/usr/bin/env bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


set -ex

GOOS=linux CGO_ENABLED=0 go build -o vault-auth-plugin-wordle cmd/vault-auth-plugin-wordle/main.go

docker kill vaultplg 2>/dev/null || true
tmpdir=$(mktemp -d vaultplgXXXXXX)
mkdir "$tmpdir/data"
chmod 777 "$tmpdir/data"
docker pull hashicorp/vault
TZ=${TZ:-America/Los_Angeles}
docker run --rm -d -p8200:8200 --name vaultplg -v "$(pwd)/$tmpdir/data":/data -e TZ=${TZ} -v $(pwd):/wordle --cap-add=IPC_LOCK -e 'VAULT_LOCAL_CONFIG=
{
  "backend": {"file": {"path": "/data"}},
  "listener": [{"tcp": {"address": "0.0.0.0:8200", "tls_disable": true}}],
  "plugin_directory": "/wordle",
  "log_level": "debug",
  "disable_mlock": true,
  "api_addr": "http://localhost:8200"
}
' hashicorp/vault server
sleep 1

export VAULT_ADDR=http://localhost:8200

initoutput=$(vault operator init -key-shares=1 -key-threshold=1 -format=json)
vault operator unseal $(echo "$initoutput" | jq -r .unseal_keys_hex[0])

export VAULT_TOKEN=$(echo "$initoutput" | jq -r .root_token)

vault write sys/plugins/catalog/auth/wordle-auth-plugin \
    sha_256=$(shasum -a 256 vault-auth-plugin-wordle | cut -d' ' -f1) \
    command="vault-auth-plugin-wordle"

vault auth enable \
    -path="wordle" \
    -plugin-name="wordle-auth-plugin" \
    -plugin-version=0.2.0 \
    plugin

vault read -field=plugin_version sys/auth/wordle/tune
WORDLE=`curl -sL https://www.nytimes.com/svc/wordle/v2/$(date +%F).json | jq -r .solution`
VAULT_TOKEN=  vault write auth/wordle/login wordle="${WORDLE}"
