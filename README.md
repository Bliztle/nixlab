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

## Secrets

Secrets are encrypted in `secrets/secrets.yaml` with SOPS. Recipient policy is defined in `.sops.yaml`, and `modules/sops.nix` maps encrypted keys to runtime files. Secret editing is deliberately a manual owner task; automated agents must not decrypt, print, edit, generate, or re-encrypt secret values.

When configuration needs a new secret, add or review the non-secret SOPS wiring separately, determine the expected key name and value format, generate or retrieve the value outside the agent workflow, and then edit the encrypted file manually with SOPS.

## Known issues and debt

This is a living register, not a claim that every item should be fixed immediately. Changes that resolve an item should update or remove it here; newly confirmed out-of-scope findings should be added without silently fixing them.

- `nix flake check` warns that the deploy-rs `deploy` output is unknown to the generic flake checker.
- Alejandra currently reports formatting changes needed in five files: `configuration.nix`, `options.nix`, `modules/neovim.nix`, `modules/wireguard.nix`, and the Pi hardware configuration.
- Statix reports existing style warnings, primarily repeated dotted attribute keys and empty argument patterns.
- Deadnix reports unused arguments in the inactive WireGuard module and the generated Pi hardware configuration.
- `custom.wireguard = true` on the Pi currently has no effect because the WireGuard implementation is commented out.
- The DDNS updater secret is installed with mode `0666`, making it readable and writable by every local user and process.
- Reusable password hashes are committed in the public host configurations. Even though SSH password authentication is disabled, public hashes permit offline password guessing.
- The shared `nixos` user has passwordless sudo. An existing comment indicates an intention to replace this with a more constrained sudo-over-SSH design.
- TCP ports 53, 80, 443, and 8384 are opened in shared configuration, so their necessity and host scope should be reviewed.
- There is no CI by design. Local evaluation and documented checks are the validation workflow.
