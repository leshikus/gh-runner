#!/bin/sh

set -eu
set -vx

token="$1"
repo_path="$2"
shift 2

test -n "$repo_path"
echo "Get a runner token for $repo_path"

curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $token" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$repo_path/actions/runners/registration-token | jq -r .token >./ghr-token

./config.sh --url https://github.com/$repo_path --token $(cat ./ghr-token) --unattended --replace --ephemeral "$@"
./run.sh

