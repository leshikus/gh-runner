# gh-runner

Run a self-hosted docker-based github runner: create the docker image, launche the container and register the runner with Github.

```
Usage:
    run.sh [OPTIONS] runner_name
        runner_name  should contain a name of the repository, e.g. leshikus/gh-runner/test
Options:
    --privileged        run the runner in privileged mode
    -t|--token [TOKEN]  user token for the self-hosted runner
                        go to Settings -> Runners for your repo
    -l|--label [LABEL]  mark the runner with the label instead of the name
    -nr|--no-rebuild    do not rebuild the contaner
    -r|--remove         unregister the runner and remove the container
    -s|--skip-check     skip runner_name sanity check
    -c|--context        a directory with a custom `Dockerfile.orig`
    -v|--verbose        add a debug output
```

## How to browse logs

For an example container `leshikus/gh-runner/test` logs can be viewed via
    `view $HOME/.config/gh-runner/leshikus.gh-runner.test/logs`
    and `docker logs leshikus.gh-runner.test`


