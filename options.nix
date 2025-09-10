{ lib, ... }:
{
  options.custom = {
    laptop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Is this a laptop system? If so, we need to enable battery and lid features.";
    };
    media = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Turn on jellyfin, audiobookshelf, and related services";
    };
    wireguard = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Should this act as a wireguard vpn server?";
    };
  };
}
