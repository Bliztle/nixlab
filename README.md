# Fluxlab

My homelab managed with NixOS and Flux CD.

## TODO

### DependsOn

Multiple ressources in the cluster rely on other ressources already being available.
So far, this has been handled by committing and reconciling some ressources before
others, which is not ideal, and does not allow for a clean reinstall of the cluster.
Splitting these into multiple kustomizations and using dependsOn is a solution
yet implemented.

This regards the following ressources:

- [ ] MetalLB
    - IPAddressPool & L2Announcement relies on metallb-release
- [ ] Media
    - jellyfin-release, audiobookshelf-release, and <file browser> relies on media-pvc

### Pihole

- [ ] Figure out sops for flux, to set password and share it with external-dns

### External-dns

This is not active yet but should be set up later. It was postponed as Bitnami stopped 
support of their external-dns chart with built-in pihole support, and i need to read
about the official chart and how to set it up for this purpoose.

