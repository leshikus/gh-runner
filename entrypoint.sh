#!/bin/sh

set -eu
#set -vx
curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer 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" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/intel-ai/icl/actions/runners/registration-token

./config.sh --name $name --labels $runner_label --url $url --token $token --unattended --replace --ephemeral "$@"
./run.sh

