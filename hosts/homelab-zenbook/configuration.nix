{...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.nixos.hashedPassword = "$y$j9T$34zgPEP/8EJQk4h/P3Hqs0$4SF2QpFXOUCkQwwxVyKNwU8lX4QBgc/AzOM4zQZA/5D";

  # Options
  custom.laptop = true;
  custom.k3s = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
