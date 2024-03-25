### Install Multipass

Use the following command: `snap install multipass`

### Set Blueprints Location

Edit the multipassd unit file `sudo systemctl edit snap.multipass.multipassd.service`:
```
[Service]
Environment="MULTIPASS_BLUEPRINTS_URL=https://github.com/canonical/multipass-blueprints/archive/refs/heads/other-distros.zip"
```

Restart the service `sudo snap restart multipass`

Test an alternative image `multipass launch rocky`


### Set Proxy

Use commands, you will need both for a blueprint to work:
```
snap set system proxy.http="http://<proxy_addr>:<proxy_port>"
snap set system proxy.https="http://<proxy_addr>:<proxy_port>"
```
