# GitHub runner for Rocky Linux image bundling

Set `TOKEN` from Github. Export `no_proxy`, `http_proxy`, `https_proxy` if needed. Run

```
sh run.sh --context packer --device /dev/kvm --device /dev/fuse --token $TOKEN intel-ai/icl/packer-1
```

Notes:

* End runner names with a number if you want to have several runners run in parallel. These numbers are used to define a separate cluster network.
* If you restart a runner, then just omit `--token $TOKEN` option, it will use cached credentials.

