# Nixlab

Personal NixOS homelab, configured with flakes and deployed with deploy-rs.

## Hosts

| Host | Architecture | Address | Status |
| --- | --- | --- | --- |
| `homelab-zenbook` | `x86_64-linux` | `10.0.0.8` | Active |
| `homelab-pi` | `aarch64-linux` | `10.0.0.6` | Not deployed |

Shared configuration lives in `configuration.nix` and `modules/`; host-specific
settings live in `hosts/`. `flake.nix` defines the hosts and dependencies.

## Services

The Zenbook runs Jellyfin, Audiobookshelf, File Browser, Syncthing, qBittorrent,
Radarr, Sonarr, Prowlarr, Bazarr, Seerr, FlareSolverr, DDNS Updater, and APCOA automation.

Teamtype is configured as a permanent collaboration peer for `uni/specialization`.
Project files and peer state live under `/var/lib/teamtype-specialization`.
Connect using the Teamtype CLI and its Neovim or VS Code plugin; see the
[connection instructions](AGENTS.md#teamtype-for-unispecialization).

Media Web UIs are available on the LAN at
`http://<service>.internal.bliztle.com`, where `<service>` is `qbittorrent`,
`radarr`, `sonarr`, `prowlarr`, `bazarr`, or `seerr`. These names resolve to
`10.0.0.8` and currently use HTTP. FlareSolverr is an internal API for Prowlarr.

Only qBittorrent uses the Proton VPN; other services use the normal connection.
Downloads live in `/mnt/hdd_storage_01/media/downloads`, with movie and TV libraries
under `/mnt/hdd_storage_01/media/media/{movies,tv}`. Application setup is managed
through the Web UIs.

## Working with the configuration

```bash
nix develop
nix flake check --no-build --no-write-lock-file
deploy .#homelab-zenbook
```

Deployment builds on the target host. Secrets are managed manually with SOPS in
`secrets/secrets.yaml`; `.sops.yaml` defines recipients.

[AGENTS.md](AGENTS.md) contains contributor guidance, full validation commands,
operational reference, and known issues.
