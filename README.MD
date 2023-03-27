# gh-runner

The Dockerfile used to build a self-hosted runner

## Add a new runner

In this example, we add a new runner 'leshikus.gh-runner.test' for the leshikus/gh-runner repo.
Please use your own path.

`CI_DOCKER=leshikus/gh-runner/test ./rebuild.sh & tail -f ./leshikus.gh-runner.test.log`

This will build the image and run the runner. However, before you go, you have to add the runner instance to your repo.

## Update the runner token

Go to `Settings => Runners` for your repo, add new runner, copy the token

`echo LONGLONGTOKENFROMGITHUB > ./leshikus.gh-runner.test.token`

`CI_DOCKER=leshikus/gh-runner/test ./update-token.sh`

This will update the token inside the container, then register the runner with Github.

## Done

That's all, folks!

