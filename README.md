# gh-runner

Run a self-hosted docker-based github runner. It creates a docker image, launches the container and registers the runner with Github.

Usage:
    run.sh [OPTIONS] runner_name
        runner_name  should contain a name of a repository, e.g. leshikus/gh-runner/test
Options:
    -r|--rebuild        rebuild docker image
    -r|--token [TOKEN]  a token for registration


## How to get the runner token

Go to `Settings => Runners` for your repo, add new runner, copy the token

