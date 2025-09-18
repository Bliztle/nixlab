{
  pkgs,
  lib,
  config,
  ...
}:
let
  hdd = "/mnt/hdd_storage_01";
  mediaDir = "${hdd}/media";
  syncDir = "${hdd}/syncthing";
in
lib.mkIf config.custom.media {

  services.jellyfin.enable = true;

  services.audiobookshelf = {
    enable = true;
    port = 8083;
  };

  services.filebrowser = {
    enable = true;
    settings = {
      port = 8084;
      root = "${mediaDir}/media";
    };
  };

  services.syncthing = {
    enable = true;
    dataDir = "${syncDir}";
    guiAddress = "0.0.0.0:8384"; # Default
    openDefaultPorts = true;
    settings = {
      devices.framework = {
        id = "7VE4AEN-CYY4UKI-R7GH3BB-PJOVQEB-JE5EDRT-L2JPWSB-RT3VEWT-ZOFYVQA";
        autoAcceptFolders = true;
      };

      devices.omen = {
        id = "MXOAWAD-CX3FCZK-RRVNVZZ-PJYAJAS-NH3FRPQ-NJGEO3X-XG6KWWY-26G6YAC"; # Replace with actual device ID
        autoAcceptFolders = true;
      };

      folders."uni" = {
        devices = [ "framework" "omen" ];
        versioning.type = "simple";
        path = "${syncDir}/uni";
      };

      options.urAccepted = -1;
    };
  };

  services.nginx = {
    enable = true;
    defaultHTTPListenPort = 80;
    defaultSSLListenPort = 443;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    virtualHosts = {
      "home.bliztle.com" = {
        default = true;
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          return = 404;
        };
      };
      "jellyfin.bliztle.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:8096";
          proxyWebsockets = true;
        };
      };
      "audiobookshelf.bliztle.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:8083";
          proxyWebsockets = true;
        };
      };
      "files.internal.bliztle.com" = {
        # Allow only local network access
        listen = [
          {
            addr = "10.0.0.8";
            port = 80;
            ssl = false;
          }
        ];
        locations."/" = {
          proxyPass = "http://localhost:8084";
          proxyWebsockets = true;
          extraConfig = ''
            allow 10.0.0.0/24;
            deny all;
          '';
        };
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "mail+acme@bliztle.com";
  };
}
