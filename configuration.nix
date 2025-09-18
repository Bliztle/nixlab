{
  pkgs,
  meta,
  # lib,
  # config,
  ...
}:
{
  imports = [
    ./modules/neovim.nix
    ./modules/sops.nix
    ./modules/shell.nix
    ./modules/laptop.nix
    ./modules/services.nix
  ];

  security.sudo.wheelNeedsPassword = false; # Replace this with sudo-over-ssh

  programs.nix-ld.enable = true; # Allow dynamic linking of nix packages

  networking.hostName = meta.hostname; # Define your hostname.

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Copenhagen";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "da_DK.UTF-8";
    LC_IDENTIFICATION = "da_DK.UTF-8";
    LC_MEASUREMENT = "da_DK.UTF-8";
    LC_MONETARY = "da_DK.UTF-8";
    LC_NAME = "da_DK.UTF-8";
    LC_NUMERIC = "da_DK.UTF-8";
    LC_PAPER = "da_DK.UTF-8";
    LC_TELEPHONE = "da_DK.UTF-8";
    LC_TIME = "da_DK.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "dk";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "dk-latin1";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.nixos = {
    isNormalUser = true;
    description = "nixos";
    extraGroups = [
      "networkmanager"
      "wheel"
      "media"
    ];
    packages = with pkgs; [ ];
    openssh.authorizedKeys.keys = [
      # Added this as deployment prompts yubikey 4 times per host
      # # # NVM, HAVING SSH CONFIGURED TO CONFIRM MEANS IT PROMPTS FOR ANY KEY
      # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMAYX+rUTXgpn6DyPfWB6tiPGpHSGkDOoVXwE2xfTnRH bliztle@zenbook"
      # Yubikeys
      "sk-ecdsa-sha2-nistp256@openssh.com AAAAInNrLWVjZHNhLXNoYTItbmlzdHAyNTZAb3BlbnNzaC5jb20AAAAIbmlzdHAyNTYAAABBBNdyTSPteztylzzDebHqctbDo/XmoYI10JAkh+M0sSlevcvZbtFWID10D8Be89xFIHohLBk39i8nzTVbLAjP5IoAAAAEc3NoOg== yubikey-station"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIKZr8Sjw7Bab9e7/8SEnrVJp48PwIOarYLQsstwacFQaAAAABHNzaDo= yubikey-float"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH3tQUrCi3I5hRkS1zeQ93nlo7o+5Xx0ZcoE0wxdtHXF bliztle@framework"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM7qNRrY3q4/D2V/Ef4S7TJtcELcjpSG/bbrF/HRCM6x bliztle@omen"
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    btop
    git
    cryptsetup
    yubioath-flutter # 2FA gui for getting keys
    pam_u2f # General purpose pam u2f. Enough for yubikey 2fa
    yubikey-manager # Yubikey management tool - ykman
    yubikey-personalization
  ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    53 # DNS
    80 # HTTP
    443 # HTTPS
    8384 # Syncthing
  ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
