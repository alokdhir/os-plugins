# OPNsense plugins by Alok Dhir

A package repository for two [OPNsense](https://opnsense.org) plugins:

- **[Loupe](https://github.com/alokdhir/os-loupe)** (`os-loupe`): per-device traffic. Which device on your network talked to which site or service, how much and when, with devices named and typed automatically.
- **[eero](https://github.com/alokdhir/os-eero)** (`os-eero`): status and history of an eero mesh Wi-Fi network: units, clients and network settings.

## Install

On the OPNsense box, from the console (option 8, *Shell*) or SSH, as root, add the repository once:

```sh
fetch -o /usr/local/etc/ssl/dhir-os-plugins.pub https://alokdhir.github.io/os-plugins/dhir-os-plugins.pub
fetch -o /usr/local/etc/pkg/repos/dhir-os-plugins.conf https://alokdhir.github.io/os-plugins/dhir-os-plugins.conf
pkg update
```

Then install the plugins from **System → Firmware → Plugins**. Updates arrive with OPNsense's own, under **System → Firmware → Updates**.

The repository is signed: `pkg` checks every update against the public key fetched above (`dhir-os-plugins.pub`), so a tampered package or index is refused.

To remove the repository: `rm /usr/local/etc/pkg/repos/dhir-os-plugins.conf /usr/local/etc/ssl/dhir-os-plugins.pub` (installed plugins stay).

Requires OPNsense 26.x. The packages hold no compiled code, so they work on any architecture.

## Source and license

Both plugins are open source under the BSD 2-Clause license, the same as OPNsense itself: every line is on GitHub to read and review.

## What's here

- `dhir-os-plugins.conf`: the repository definition for `pkg`.
- `dhir-os-plugins.pub`: the public key the repository index is signed with.
- `repo/`: the packages and their index, served by GitHub Pages.
- `tools/publish.sh`: builds both plugins from their repositories with OPNsense's plugin tooling and publishes them here.

These plugins are not part of OPNsense and are not supported by the OPNsense project. Questions and bugs go to each plugin's repository.
