# gh-runner

Run a self-hosted docker-based github runner: create the docker image, launche the container and register the runner with Github.

```
Usage:
    run.sh [OPTIONS] runner_name
        runner_name  should contain a name of the repository, e.g. leshikus/gh-runner/test
Options:
    -t|--token [TOKEN]  user token for the repo, see the required scope at
        https://github.com/actions/actions-runner-controller/blob/master/docs/authenticating-to-the-github-api.md#deploying-using-pat-authentication
    -l|--label [LABEL]  mark the runner with the label instead of the name
    -nr|--no-rebuild    do not rebuild the contaner
    -r|--remove         unregister the runner and remove the container
    -s|--skip-check     skip runner_name sanity check
    -c|--context        a directory with a custom `Dockerfile.orig`
    -v|--verbose        add a debug output
```

## How to get the runner token

Go to `Settings => Runners` for your repo, add a new runner, copy the token.


## How to browse logs

For an example container `leshikus/gh-runner/test` logs can be viewed via
    `view /tmp/$USER/gh-runner/leshikus.gh-runner.test/logs`
    and `docker logs leshikus.gh-runner.test`


