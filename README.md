# Nixlab

NixOS configuration for a small personal homelab. The repository is operated by one person but is public and may be useful as a reference for other flakes.

## Hosts

| Host | Architecture | Address | Status | Enabled role/features |
| --- | --- | --- | --- | --- |
| `homelab-zenbook` | `x86_64-linux` | `10.0.0.8` | Actively deployed | Laptop power policy, media services, Syncthing, reverse proxy, DDNS updater, APCOA bot |
| `homelab-pi` | `aarch64-linux` | `10.0.0.6` | Declared but not currently deployed | Intended WireGuard role; currently no effective WireGuard configuration |

Both hosts are generated from the inventory in `flake.nix`. They share `configuration.nix`, the custom options in `options.nix`, and the modules under `modules/`; host directories contain boot, hardware, feature-selection, and state-version settings.

The Zenbook currently serves Jellyfin, Audiobookshelf, File Browser, Syncthing, DDNS Updater, nginx/ACME endpoints, and APCOA automation. Persistent media and synchronization data live below `/mnt/hdd_storage_01`.

## Working with the flake

Enter the development environment, which provides deploy-rs, SOPS, Alejandra, Statix, and Deadnix:

```bash
direnv allow
# or
nix develop
```

Evaluate the flake and both NixOS configurations without building:

```bash
nix flake check --no-build --no-write-lock-file
nix eval --raw .#nixosConfigurations.homelab-zenbook.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.homelab-pi.config.system.build.toplevel.drvPath
```

The explicit derivation evaluations are important: the generic flake check performs a shallower check and can pass even when constructing a host's top-level derivation fails.

Check formatting and run advisory static analysis:

```bash
alejandra --check .
statix check .
deadnix --fail .
```

Deployment is intentionally manual. The normal command is:

```bash
deploy .#homelab-zenbook
```

deploy-rs is configured with `remoteBuild = true`, so the target performs the build. The Pi must not be deployed merely because it remains declared in the flake.

Deployment preflight checks run locally. Each architecture's checks include only matching hosts, so checking the Zenbook from an x86 laptop does not require building the ARM Pi configuration.

## Secrets

Secrets are encrypted in `secrets/secrets.yaml` with SOPS. Recipient policy is defined in `.sops.yaml`, and `modules/sops.nix` maps encrypted keys to runtime files. Secret editing is deliberately a manual owner task; automated agents must not decrypt, print, edit, generate, or re-encrypt secret values.

When configuration needs a new secret, add or review the non-secret SOPS wiring separately, determine the expected key name and value format, generate or retrieve the value outside the agent workflow, and then edit the encrypted file manually with SOPS.

## qBittorrent through Proton VPN

The Zenbook configuration includes qBittorrent in the `qbittorrent` network namespace.
Its WireGuard interface is the only internet route; a filtered veth link permits
only replies to host-initiated Web UI requests. DNS uses Proton's `10.2.0.1` inside
the namespace. IPv6 is disabled there because this Proton configuration supplies
only an IPv4 address. Host routing and DNS are unchanged.

The owner-managed SOPS key `wg_zenbook_proton_qbittorrent_dk` must contain the full
WireGuard configuration, including its private key. This module expects the
provided `Address = 10.2.0.2/32` and `DNS = 10.2.0.1`; changes to those values
require corresponding module changes. Select a Proton P2P server with NAT-PMP
enabled. The configuration is stripped and loaded at runtime, never embedded in
the Nix store. WireGuard configuration hooks are not executed.

After deployment, point `qbittorrent.internal.bliztle.com` at `10.0.0.8` in LAN
DNS (or a client hosts file), then open `http://qbittorrent.internal.bliztle.com`.
nginx restricts access to `10.0.0.0/24`. Log in as `admin` using the temporary
password from `sudo journalctl -u qbittorrent.service`, then set a password in the
Web UI. Passwords and other user settings persist across restarts. Only loopback
inside the namespace bypasses authentication for the port-forwarding helper;
nginx's connection does not. The Web UI is blocked on the VPN interface.

Downloads default to `/mnt/hdd_storage_01/media/downloads` with media-group access.
`qbittorrent-port-forward.service` renews Proton's TCP and UDP mappings and updates
qBittorrent's listening port automatically, including after port changes. Keep
qBittorrent's own UPnP/NAT-PMP option disabled; no home-router forwarding is needed.
Lease failures are retried and logged, and may interrupt inbound connectivity;
they do not create a route outside the VPN.

For owner-run post-deployment checks:

```bash
sudo systemctl status qbittorrent-vpn qbittorrent qbittorrent-port-forward
sudo journalctl -u qbittorrent-port-forward -n 30
sudo ip -n qbittorrent route
sudo ip netns exec qbittorrent nft list ruleset
```

Check the namespace's public IP against the host's using an HTTP client with
`sudo ip netns exec qbittorrent`; it should be Proton's exit IP. To test the kill
switch, bring `qbt-wg` down inside that namespace and confirm internet requests and
torrents fail while other host services remain reachable, then bring it up again.
Restarting `qbittorrent-vpn` also recreates the namespace and restarts its dependent
services. Local evaluations do not verify the remote handshake, inbound peer
reachability, or activation; those require post-deployment checks.

## Media automation

Radarr, Sonarr, Prowlarr, Bazarr, and Seerr are enabled on the Zenbook using their
native NixOS options. Each can be enabled or disabled independently in the host
configuration:

```nix
services.radarr.enable = true;
services.sonarr.enable = true;
services.prowlarr.enable = true;
services.bazarr.enable = true;
services.seerr.enable = true;
```

`modules/media-automation.nix` adds storage permissions and an nginx virtual host
only for enabled services. These services use the host's normal internet
connection. Only qBittorrent is inside the VPN namespace. The Pi leaves all five
disabled.

Point these names at `10.0.0.8` in LAN DNS or a client hosts file. Open them over
HTTP; nginx allows only `10.0.0.0/24`. Backend ports are not opened in the firewall.
Radarr, Sonarr, and Prowlarr additionally bind to loopback.

| Service | LAN Web UI | Local API address |
| --- | --- | --- |
| Radarr | `http://radarr.internal.bliztle.com` | `http://127.0.0.1:7878` |
| Sonarr | `http://sonarr.internal.bliztle.com` | `http://127.0.0.1:8989` |
| Prowlarr | `http://prowlarr.internal.bliztle.com` | `http://127.0.0.1:9696` |
| Bazarr | `http://bazarr.internal.bliztle.com` | `http://127.0.0.1:6767` |
| Seerr | `http://seerr.internal.bliztle.com` | `http://127.0.0.1:5055` |

After deployment, complete the apps' initial setup and authentication in their
Web UIs. Configure the connections below manually; API keys, provider credentials,
and qBittorrent credentials belong in the apps' private state, not Nix expressions.

1. In Radarr, use `/mnt/hdd_storage_01/media/media/movies` as the root folder; in
   Sonarr, use `/mnt/hdd_storage_01/media/media/tv`. Add qBittorrent as a download
   client in each with host `10.200.200.2`, port `8080`, SSL off, and your qBittorrent
   username/password. Use separate `radarr` and `sonarr` categories. No remote path
   mapping is needed: all services see the same filesystem paths.
2. In Prowlarr, add your indexers and add Radarr/Sonarr under Settings → Apps using
   the local API addresses above and their API keys. Use `http://127.0.0.1:9696`
   for Prowlarr's own server URL in these connections.
3. In Bazarr, connect to Radarr/Sonarr on `127.0.0.1` and their respective ports
   with their API keys, then configure subtitle providers and language profiles.
4. In Seerr, connect to Jellyfin at `http://127.0.0.1:8096`, and Radarr/Sonarr at
   their local API addresses. Select the root folders and quality profiles you
   configured above. Add the movies/TV folders as Jellyfin libraries if needed.

Radarr, Sonarr, Bazarr, and qBittorrent share the `media` group. New movie/TV
directories use mode `2775`, and media writers use umask `0002` to support imports,
hardlinks, and subtitle writes. Downloads and libraries are on the same HDD
filesystem. Existing file permissions are not changed recursively; files moved
into these directories must already grant the media group the access they need.

Application databases/configuration remain under their default `/var/lib`
directories. Seerr uses its current `/var/lib/seerr` layout (`stateRevision = 1`);
the host's `system.stateVersion` is unchanged. Back up application state as well
as media. Service enablement is declarative; indexers, libraries, profiles, and
connections are managed in the apps.

Owner-run checks after deployment:

```bash
sudo systemctl status radarr sonarr prowlarr bazarr seerr
```

Use each app's connection-test buttons to verify the integrations, then test a
download/import and a subtitle write. Local evaluation cannot verify these live
connections or provider credentials.

## Known issues and debt

This is a living register, not a claim that every item should be fixed immediately. Changes that resolve an item should update or remove it here; newly confirmed out-of-scope findings should be added without silently fixing them.

- `nix flake check` warns that the deploy-rs `deploy` output is unknown to the generic flake checker.
- Alejandra currently reports formatting changes needed in seven files: `configuration.nix`, `flake.nix`, `options.nix`, `modules/neovim.nix`, `modules/services.nix`, `modules/wireguard.nix`, and the Pi hardware configuration.
- Statix reports existing style warnings, primarily repeated dotted attribute keys and empty argument patterns.
- Deadnix reports unused arguments in the inactive WireGuard module and the generated Pi hardware configuration.
- `custom.wireguard = true` on the Pi currently has no effect because the WireGuard implementation is commented out.
- The DDNS updater secret is installed with mode `0666`, making it readable and writable by every local user and process.
- Reusable password hashes are committed in the public host configurations. Even though SSH password authentication is disabled, public hashes permit offline password guessing.
- The shared `nixos` user has passwordless sudo. An existing comment indicates an intention to replace this with a more constrained sudo-over-SSH design.
- TCP ports 53, 80, 443, and 8384 are opened in shared configuration, so their necessity and host scope should be reviewed.
- There is no CI by design. Local evaluation and documented checks are the validation workflow.
