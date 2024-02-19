# Build X1 GitHub runner image for deploying X1 to Vagrant VMs

Run the following:


```
sh gh-runner/run.sh  --token $TOKEN --context vagrant $RUNNER_NAME --labels vagrant-libvirt --become
```

Notes:

* End runner names with a number if you want to have several runners run in parallel. These numbers are used to define a separate cluster network.
* If you restart a runner, then just omit `--token $TOKEN` option, it will use cached credentials.

