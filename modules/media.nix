{
  lib,
  config,
  ...
}:
lib.mkIf config.custom.media {
  services.jellyfin = {
    enable = true;
    cacheDir = "/mnt/hdd_storage_01/media/jellyfin/cache";
    configDir = "/mnt/hdd_storage_01/media/jellyfin/config";
    dataDir = "/mnt/hdd_storage_01/media/jellyfin";
    logDir = "/mnt/hdd_storage_01/media/jellyfin/log";
  };

  # services.audiobookshelf = {
  #   enable = true;
  #   dataDir = "/mnt/hdd_storage_01/media/audiobookshelf";
  #   port = 8083;
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
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "mail+acme@bliztle.com";
  };
}
