{
  description = "Homelab NixOS Flake shared across all homelab devices";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apcoabot = {
      url = "github:Bliztle/apcoabot";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    deploy-rs,
    sops-nix,
    apcoabot,
    ...
  }: let
    nodes = [
      {
        hostname = "homelab-zenbook";
        ssh_hostname = "10.0.0.8";
        system = "x86_64-linux";
        role = "server";
      }
      {
        hostname = "homelab-pi";
        ssh_hostname = "10.0.0.6";
        system = "aarch64-linux";
        role = "agent";
      }
    ];
    systems = nixpkgs.lib.unique (map (node: node.system) nodes);
  in {
    # --- Top-level nixosConfigurations ---
    nixosConfigurations = builtins.listToAttrs (
      map (node: {
        name = node.hostname;
        value = nixpkgs.lib.nixosSystem {
          specialArgs = {
            meta = node;
          };
          inherit (node) system;
          modules =
            [
              ./options.nix
              ./hosts/${node.hostname}/configuration.nix
              ./configuration.nix
              sops-nix.nixosModules.sops
            ]
            ++ nixpkgs.lib.optionals (node.hostname == "homelab-zenbook") [
              apcoabot.nixosModules.default
            ];
        };
      })
      nodes
    );

    # --- Top-level deploy-rs config ---
    deploy.nodes = builtins.listToAttrs (
      map (node: {
        name = node.hostname;
        value = {
          hostname = node.ssh_hostname;
          sshUser = "nixos";
          remoteBuild = true;
          fastConnection = true;
          profiles.system = {
            user = "root";
            path = deploy-rs.lib.${node.system}.activate.nixos self.nixosConfigurations.${node.hostname};
          };
        };
      })
      nodes
    );

    # Validate the deploy-rs schema and activation paths with `nix flake check`.
    checks = nixpkgs.lib.genAttrs systems (
      system: deploy-rs.lib.${system}.deployChecks self.deploy
    );

    # Development tooling is available for every architecture in the host inventory.
    devShells = nixpkgs.lib.genAttrs systems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          packages = [
            pkgs.alejandra
            pkgs.deadnix
            pkgs.deploy-rs
            pkgs.sops
            pkgs.statix
          ];
        };
      }
    );

    formatter = nixpkgs.lib.genAttrs systems (
      system: nixpkgs.legacyPackages.${system}.alejandra
    );
  };
}
