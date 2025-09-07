{ ... }:

{
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;

    secrets.wg0_pi_public = {};
    secrets.wg0_pi_private = {};
    secrets.wg0_lenovo_public = {};
    secrets.wg0_lenovo_private = {};
    secrets.k3s_token = {};

    # secrets.luks_cryptbay = {
      # This puts the secret where initrd can find it
      # path = "/etc/secrets/initrd/luks_cryptbay_key";
      # mode = "0400";
      # owner = "root";
      # group = "root";
      # neededForUsers = true;
      # This ensures the secret is available when initrd starts up
    #   restartUnits = [ "initrd-cryptsetup.service" ];
    # };
  };
}
