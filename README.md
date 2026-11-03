# OPNsense plugins by Alok Dhir

A package repository for two [OPNsense](https://opnsense.org) plugins:

- **[Loupe](https://github.com/alokdhir/os-loupe)** (`os-loupe`): per-device traffic. Which device on your network talked to which site or service, how much and when, with devices named and typed automatically.
- **[eero](https://github.com/alokdhir/os-eero)** (`os-eero`): status and history of an eero mesh Wi-Fi network: units, clients and network settings.

## Install

On the OPNsense box, from the console (option 8, *Shell*) or SSH, as root, add the repository once:

```sh
fetch -o /usr/local/etc/pkg/repos/dhir-os-plugins.conf https://alokdhir.github.io/os-plugins/dhir-os-plugins.conf
pkg update
```

Then install the plugins from **System → Firmware → Plugins** (or `pkg install os-loupe os-eero`). Updates arrive with OPNsense's own, under **System → Firmware → Updates**.

To remove the repository: `rm /usr/local/etc/pkg/repos/dhir-os-plugins.conf` (installed plugins stay).

Requires OPNsense 26.x. The packages hold no compiled code, so they work on any architecture.

## What's here

- `dhir-os-plugins.conf`: the repository definition for `pkg`.
- `repo/`: the packages and their index, served by GitHub Pages.
- `tools/publish.sh`: builds both plugins from their repositories with OPNsense's plugin tooling and publishes them here.

These plugins are not part of OPNsense and are not supported by the OPNsense project. Questions and bugs go to each plugin's repository.
