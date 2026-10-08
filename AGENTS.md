# Agent guidance

## Purpose and current state

This repository defines a personal NixOS homelab. It is public and is also used as a reference by other people, so keep changes understandable and never commit private material.

- `homelab-zenbook` is the only actively deployed host.
- `homelab-pi` is retained but is not currently deployed.
- Shared changes must continue to evaluate for both hosts.
- The repository owner operates the infrastructure alone.

Read `README.md` before making changes. It provides the human-facing overview and normal commands. Detailed operational notes and the issue register live in this file.

## Repository map

- `flake.nix`: inputs, host inventory, NixOS configurations, deploy-rs nodes, and the development shell.
- `configuration.nix`: settings and modules shared by all hosts.
- `options.nix`: project-specific `custom.*` NixOS options.
- `hosts/<hostname>/`: host configuration and generated hardware configuration.
- `modules/`: feature modules. Most are shared and conditionally enabled through `custom.*` options.
- `secrets/secrets.yaml` and `.sops.yaml`: encrypted SOPS data and recipient policy; secret contents are owner-managed.

## Working agreement

1. Start with `git status --short --branch` and preserve unrelated or pre-existing worktree changes.
2. Inspect the relevant option, host, and module definitions before editing. Prefer small changes that follow the existing module structure.
3. Do not silently fix adjacent findings. Record newly confirmed issues in the issue register in AGENTS.md when they are outside the requested scope.
4. When resolving a documented issue, update or remove its AGENTS.md entry in the same change. Keep the issue register factual and current.
5. Leave changes unstaged unless the owner explicitly requests staging or commits. Never push without explicit permission.

## Validation

Evaluations are safe to run without asking. Validate both hosts after shared changes and the affected host after host-only changes.

```bash
nix flake check --no-build --no-write-lock-file
nix eval --raw .#nixosConfigurations.homelab-zenbook.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.homelab-pi.config.system.build.toplevel.drvPath
```

The development shell provides deployment, secret-management, formatting, and static-analysis tools:

```bash
nix develop
alejandra --check .
statix check .
deadnix --fail .
```

Some quality commands have existing failures documented in the issue register below. Report whether a change introduces new failures; do not reformat or clean unrelated files unless asked. A generic `nix flake check --no-build` is shallower than evaluating each system derivation, so do not use it as the sole proof of cross-host validity.

## Safety boundaries

The following require explicit owner permission for the specific task:

- Running `deploy .#homelab-zenbook` or any other deployment/activation command.
- Connecting to a homelab host, including read-only SSH or remote diagnostics. If host access would materially help, explain why and ask first.
- Creating commits, pushing branches, or changing remote GitHub state.
- Changing `flake.lock` or updating inputs unless dependency updates are part of the request.

Never decrypt, edit, generate, re-encrypt, or print secret values. When a task needs a new or changed secret, implement only the non-secret wiring if requested, then give the owner exact retrieval/generation instructions and the expected SOPS key name or data shape. The owner will edit SOPS data manually.

Treat deployments as remote builds: the current deploy-rs configuration has `remoteBuild = true`. Do not claim that a local evaluation or derivation build proves successful activation on the server.

## NixOS conventions

- Do not change `system.stateVersion` as part of an upgrade or cleanup.
- Treat `hardware-configuration.nix` as generated host hardware data; change it only for an intentional hardware/filesystem adjustment.
- Keep host-independent behavior in shared modules and host-specific activation in `hosts/<hostname>/configuration.nix` or explicit conditions.
- Preserve the distinction between declared hosts and deployed hosts. Never deploy the Pi based only on its presence in the flake.
- Use Alejandra as the formatter and Statix/Deadnix as advisory static analyzers.
- Comments should explain operational intent or non-obvious constraints, not restate Nix syntax.

## Documentation scope

Keep README.md short: purpose, hosts, service access, storage, and normal commands.
Put agent instructions, implementation constraints, troubleshooting procedures,
validation details, and known issues in AGENTS.md. Do not expand the README with
session history or step-by-step service setup unless the owner requests it.

Deployment preflight checks include only hosts matching the local architecture;
checking the Zenbook from x86 does not require an ARM Pi build.

## Operational reference

These notes describe the configuration and are not authorization to access hosts,
restart services, change interfaces, or deploy. Follow the safety boundaries above
and the permissions granted in the current conversation.

### qBittorrent through Proton VPN


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

First confirm both requests succeed and compare their `ip=` lines: the namespace
must use Proton's exit IP, while the host keeps its normal public IP. The numeric
URL tests routing without depending on DNS or a configured HTTP proxy.

```bash
curl --noproxy '*' -4 --max-time 15 https://1.1.1.1/cdn-cgi/trace
sudo ip netns exec qbittorrent curl --noproxy '*' -4 --max-time 15 https://1.1.1.1/cdn-cgi/trace
```

Only after establishing working connectivity, test the kill switch. Bringing an
interface down removes its default route; bringing it up alone does not restore
that route. Always run both recovery commands below, even if a check fails.

```bash
sudo ip -n qbittorrent link set qbt-wg down
# This must fail; the equivalent host request must still succeed.
sudo ip netns exec qbittorrent curl --noproxy '*' -4 --max-time 10 https://1.1.1.1/cdn-cgi/trace
curl --noproxy '*' -4 --max-time 10 https://1.1.1.1/cdn-cgi/trace
# Recover the interface AND its route, then confirm connectivity returns.
sudo ip -n qbittorrent link set qbt-wg up
sudo ip -n qbittorrent route replace default dev qbt-wg
sudo ip netns exec qbittorrent curl --noproxy '*' -4 --max-time 15 https://1.1.1.1/cdn-cgi/trace
```

Restarting `qbittorrent-vpn` also recreates the namespace and restarts its dependent
services. Local evaluations do not verify the remote handshake, inbound peer
reachability, or activation; those require post-deployment checks.

### Media automation

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

### FlareSolverr for Prowlarr

The Zenbook enables `services.flaresolverr.enable`. FlareSolverr listens only on
`127.0.0.1:8191`, uses the host's normal connection, and has no nginx entry or
firewall opening. It does not need a DNS record. The Pi leaves it disabled.

After deployment, check `sudo systemctl status flaresolverr` and
`curl http://127.0.0.1:8191/` on the server. In Prowlarr, open
Settings → Indexers → Indexer Proxies → Add → FlareSolverr. Set the host URL to
`http://127.0.0.1:8191`, add the tag `flaresolverr`, then Test and Save. Add the same
tag to the indexers that need it on the main Indexers page. Prowlarr uses this
proxy when it detects Cloudflare protection on an indexer with a matching tag;
without matching tags the proxy is disabled. A successful proxy test confirms
connectivity, but does not guarantee every indexer's challenge can be solved.

See the [Prowlarr proxy documentation](https://wiki.servarr.com/prowlarr/settings#indexer-proxies)
and [FlareSolverr documentation](https://github.com/FlareSolverr/FlareSolverr).

### Teamtype for uni/specialization

The Zenbook imports `modules/teamtype.nix`, which enables
`teamtype-specialization.service` as an always-online Teamtype peer. The Pi does
not import it. Teamtype comes from the existing pinned nixpkgs (currently 0.9.2).
No dependency update or deployment is needed to prepare this configuration.

The dedicated `teamtype` user owns `/var/lib/teamtype-specialization` (mode 0700).
The shared project is its `project/` subdirectory; it starts empty. Teamtype
creates its identity in `project/.teamtype/key` on first service start and keeps
document history in `project/.teamtype/doc`. Preserve the entire state directory
when backing up or migrating, including hidden files. No SOPS entry is required
for this application-managed identity. Never copy it into this public repository.

The service uses the host's normal internet connection and Teamtype's default
Iroh relays/discovery. It does not host a relay, need nginx/DNS records, or open
an inbound firewall port. Direct connections are attempted where possible, with
relay fallback. `--no-join-code` avoids the Magic Wormhole pairing service;
clients instead use a persistent secret address. This is not a fully independent
networking deployment: public Iroh infrastructure remains a dependency.

After the owner deploys, run on the server:

```bash
sudo systemctl status teamtype-specialization
sudo cat /var/lib/teamtype-specialization/session.log
```

The log contains the secret address printed at startup. Treat it as an invitation
granting read/write access and share it privately with collaborators. Output stays
in this private file outside the synchronized project, not in the journal. The
file is replaced on service restart; it also contains runtime diagnostics. The
main process opens it after systemd creates the state directory. Do not use
`StandardOutput=truncate:` for this path: on first startup it is opened before
the directory exists, causing `209/STDOUT` even for `ExecStartPre`. Pre-start
diagnostics remain in the journal; they contain no invitation. The
address remains stable while `project/.teamtype/key` is preserved. Do not start a
second daemon on the server's project directory: the unit removes a stale socket
before startup to recover unattended after a crash.

On each client, install a matching Teamtype version and the
[Neovim plugin or VS Code extension](https://github.com/teamtype/teamtype#-installation).
Make sure `teamtype` is in the editor's PATH. For an empty local project directory:

```bash
mkdir -p ~/uni/specialization/.teamtype
chmod 700 ~/uni/specialization/.teamtype
cd ~/uni/specialization
```

Using a local editor, create `.teamtype/config` containing `peer=SECRET_ADDRESS`,
replacing the placeholder with the private address from the server. Set that
file's permissions to 0600, then run `teamtype join` in this directory and keep it
running while editing. Subsequent sessions also use `teamtype join` without a code.
Join from an empty directory first, then copy the initial project files into one
connected client directory. Other connected devices and the server receive them.

For this persistent workflow, do not configure a Git remote in the shared
directory: Teamtype 0.9.2 disables persistent CRDT history when it detects one.
Git metadata is excluded by default; `--sync-vcs` is intentionally not enabled.
Keep `.teamtype/` out of version control. Clients on Windows need WSL. Restarting
a local daemon may require reopening the editor to reconnect its plugin.

After deployment, verify simultaneous edits and cursors between Neovim and VS
Code, then reconnect a client and confirm its edits persist. Test a service
restart to confirm clients can reconnect with the same address. Local Nix
evaluations do not prove network connectivity, relay availability, or editor
interoperability. See upstream's [permanent-peer guide](https://teamtype.github.io/teamtype/shared-notes.html)
and [offline/Git limitations](https://teamtype.github.io/teamtype/offline-support.html).

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
