{
  pkgs,
  lib,
  config,
  ...
}:
let
  mediaDir = "/mnt/hdd_storage_01/media";
in
lib.mkIf config.custom.media {
  services.jellyfin = {
    enable = true;
    cacheDir = "${mediaDir}/jellyfin/cache.d";
    configDir = "${mediaDir}/jellyfin/config.d";
    dataDir = "${mediaDir}/jellyfin";
    logDir = "${mediaDir}/jellyfin/log.d";
  };

  # TODO Fix user permission issues preventing launch
  # services.audiobookshelf = {
  #   enable = true;
  #   dataDir = "${mediaDir}/audiobookshelf";
  #   port = 8083;
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

  services.nginx = {
    enable = true;
    defaultHTTPListenPort = 80;
    defaultSSLListenPort = 443;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    virtualHosts = {
      "default" = {
        default = true;
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
      "files.internal.bliztle.com" = {
        # Only listen on the internal IP
        # TODO: Does this actually work? All traffic is sent here through the router anyway
        #       I should look into how network interfaces actually work
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
          # Allow only local network access
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
