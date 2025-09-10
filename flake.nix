{
  description = "Homelab NixOS Flake shared across all homelab devices";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    deploy-rs.url = "github:serokell/deploy-rs";
    sops-nix.url = "github:Mic92/sops-nix";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    deploy-rs,
    sops-nix,
    flake-utils,
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
  in
    {
      # --- Top-level nixosConfigurations ---
      nixosConfigurations = builtins.listToAttrs (map (node: {
          name = node.hostname;
          value = nixpkgs.lib.nixosSystem {
            specialArgs = {meta = node;};
            system = node.system;
            modules = [
              ./options.nix
              ./hosts/${node.hostname}/configuration.nix
              ./configuration.nix
              sops-nix.nixosModules.sops
            ];
          };
        })
        nodes);

      # --- Top-level deploy-rs config ---
      deploy.nodes = builtins.listToAttrs (map (node: {
          name = node.hostname;
          value = {
            hostname = node.ssh_hostname;
            sshUser = "nixos";
            remoteBuild = true;
            fastConnection = true;
            profiles.system = {
              user = "root";
              path =
                deploy-rs.lib.${node.system}.activate.nixos
                self.nixosConfigurations.${node.hostname};
            };
          };
        })
        nodes);
    }
    # --- System-dependent outputs ---
    // flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      devShell = pkgs.mkShell {
        buildInputs = [
          deploy-rs.packages.${system}.deploy-rs
        ];
      };
    });
}
