# Agent guidance

## Purpose and current state

This repository defines a personal NixOS homelab. It is public and is also used as a reference by other people, so keep changes understandable and never commit private material.

- `homelab-zenbook` is the only actively deployed host.
- `homelab-pi` is retained but is not currently deployed.
- Shared changes must continue to evaluate for both hosts.
- The repository owner operates the infrastructure alone.

Read `README.md` before making changes. It documents the architecture, normal commands, and the living list of known issues.

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
3. Do not silently fix adjacent findings. Record newly confirmed issues in the README when they are outside the requested scope.
4. When resolving a documented issue, update or remove its README entry in the same change. Keep the issue register factual and current.
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

Some quality commands have existing failures documented in the README. Report whether a change introduces new failures; do not reformat or clean unrelated files unless asked. A generic `nix flake check --no-build` is shallower than evaluating each system derivation, so do not use it as the sole proof of cross-host validity.

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
