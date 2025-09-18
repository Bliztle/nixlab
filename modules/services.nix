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

  # services.filebrowser = {
  #   enable = true;
  #   port = 8084;
  #   root = "${mediaDir}/media";
  # };

  # TODO Fix user permission issues preventing launch
  # systemd.services.miniserve = {
  #   description = "Miniserve File Server";
  #   after = [ "network.target" ];
  #   wantedBy = [ "multi-user.target" ];
  #
  #   serviceConfig = {
  #     ExecStart = "${pkgs.miniserve}/bin/miniserve ${mediaDir}/media --port 8084 --upload-files --overwrite-files";
  #     Restart = "always";
  #     User = "nobody";
  #     Group = "nogroup";
  #     WorkingDirectory = "${mediaDir}/media";
  #   };
  # };

  # services.syncthing = {
  #   enable = true;
  #   dataDir = "${syncDir}/syncthing";
  #   guiAddress = "127.0.0.1:8384"; # Default
  #   openDefaultPorts = true;
  #   settings = {
  #     devices.framework = {
  #       autoAcceptFolders = true;
  #       id = "DEVICE_ID_HERE"; # Replace with actual device ID
  #     };
  #     folders.uni = {
  #       enable = true;
  #       devices = [ "framework" ];
  #       versioning.type = "simple";
  #     };
  #     options.urAccepted = -1;
  #   };
  # };

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
      # "files.internal.bliztle.com" = {
      #   # Only listen on the internal IP
      #   # TODO: Does this actually work? All traffic is sent here through the router anyway
      #   #       I should look into how network interfaces actually work
      #   listen = [
      #     {
      #       addr = "10.0.0.8";
      #       port = 80;
      #       ssl = false;
      #     }
      #   ];
      #   locations."/" = {
      #     proxyPass = "http://localhost:8084";
      #     proxyWebsockets = true;
      #     # Allow only local network access
      #     extraConfig = ''
      #       allow 10.0.0.0/24;
      #       deny all;
      #     '';
      #   };
      # };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "mail+acme@bliztle.com";
  };
}
