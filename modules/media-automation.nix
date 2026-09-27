{
  config,
  lib,
  ...
}: let
  cfg = config.services;
  storage = "/mnt/hdd_storage_01";
  library = "${storage}/media/media";
  ports = {
    radarr = cfg.radarr.settings.server.port;
    sonarr = cfg.sonarr.settings.server.port;
    prowlarr = cfg.prowlarr.settings.server.port;
    bazarr = cfg.bazarr.listenPort;
    seerr = cfg.seerr.port;
  };
  enabled = lib.filterAttrs (name: _: cfg.${name}.enable) ports;
  mediaWriters = builtins.filter (name: cfg.${name}.enable) ["radarr" "sonarr" "bazarr"];
in {
  users.groups.media = lib.mkIf (mediaWriters != []) {};

  services = {
    radarr = lib.mkIf cfg.radarr.enable {
      group = "media";
      settings.server.bindaddress = "127.0.0.1";
    };
    sonarr = lib.mkIf cfg.sonarr.enable {
      group = "media";
      settings.server.bindaddress = "127.0.0.1";
    };
    prowlarr = lib.mkIf cfg.prowlarr.enable {
      settings.server.bindaddress = "127.0.0.1";
    };
    bazarr = lib.mkIf cfg.bazarr.enable {
      group = "media";
    };
    # This is a new installation, so use the current state directory layout.
    seerr.stateRevision = lib.mkIf cfg.seerr.enable 1;

    nginx = lib.mkIf (enabled != {}) {
      enable = true;
      virtualHosts = lib.mapAttrs' (name: port:
        lib.nameValuePair "${name}.internal.bliztle.com" {
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString port}";
            proxyWebsockets = true;
            extraConfig = ''
              allow 10.0.0.0/24;
              deny all;
            '';
          };
        })
      enabled;
    };
  };

  systemd = {
    services = lib.mkMerge [
      (lib.genAttrs mediaWriters (_: {
        unitConfig.RequiresMountsFor = [storage];
        # Imports and subtitles must remain writable by the other media services.
        serviceConfig.UMask = lib.mkForce "0002";
      }))
      {
        # Prowlarr uses the local API; this service needs no public endpoint.
        flaresolverr = lib.mkIf cfg.flaresolverr.enable {
          environment.HOST = "127.0.0.1";
        };
      }
    ];
    tmpfiles.rules = lib.optionals (mediaWriters != []) (
      lib.optional (!config.custom.media) "d ${library} 2775 root media -"
      ++ [
        "d ${library}/movies 2775 root media -"
        "d ${library}/tv 2775 root media -"
      ]
    );
  };
}
