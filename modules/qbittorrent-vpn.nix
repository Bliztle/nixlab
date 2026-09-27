{
  config,
  pkgs,
  ...
}: let
  namespace = "qbittorrent";
  secret = config.sops.secrets.wg_zenbook_proton_qbittorrent_dk.path;
  downloads = "/mnt/hdd_storage_01/media/downloads";
  resolver = pkgs.writeText "qbittorrent-resolv.conf" "nameserver 10.2.0.1\n";
  helper = ./qbittorrent-vpn.py;
in {
  sops.secrets.wg_zenbook_proton_qbittorrent_dk = {
    mode = "0400";
    restartUnits = ["qbittorrent-vpn.service"];
  };

  networking.networkmanager.unmanaged = ["interface-name:qbt-host" "interface-name:qbt-wg"];

  services.qbittorrent = {
    enable = true;
    group = "media";
    openFirewall = false;
    extraArgs = ["--confirm-legal-notice"];
  };

  systemd = {
    tmpfiles.rules = ["d ${downloads} 2775 qbittorrent media -"];
    services = {
      qbittorrent-vpn = {
        description = "Isolated Proton WireGuard network for qBittorrent";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target" "qbittorrent.service" "qbittorrent-port-forward.service"];
        after = ["network-online.target" "sops-nix.service"];
        path = [pkgs.iproute2 pkgs.wireguard-tools pkgs.nftables pkgs.procps];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "qbittorrent-vpn";
          RuntimeDirectoryMode = "0700";
          UMask = "0077";
        };
        script = ''
          ip netns add ${namespace}
          # WireGuard keeps its encrypted transport socket in its birth namespace.
          # Only the tunnel moves; the host's routes and DNS stay unchanged.
          ip link add qbt-wg type wireguard
          # Strip wg-quick fields without executing hooks or logging key material.
          ln -s ${secret} /run/qbittorrent-vpn/proton.conf
          wg-quick strip /run/qbittorrent-vpn/proton.conf > /run/qbittorrent-vpn/wireguard.conf
          wg setconf qbt-wg /run/qbittorrent-vpn/wireguard.conf
          rm /run/qbittorrent-vpn/wireguard.conf
          ip link set qbt-wg netns ${namespace}
          ip -n ${namespace} link set lo up
          ip netns exec ${namespace} sysctl -q -w net.ipv6.conf.all.disable_ipv6=1
          ip netns exec ${namespace} sysctl -q -w net.ipv6.conf.default.disable_ipv6=1
          ip -n ${namespace} address add 10.2.0.2/32 dev qbt-wg
          ip -n ${namespace} link set qbt-wg mtu 1420 up
          ip -n ${namespace} route add default dev qbt-wg

          # This link carries only host-initiated Web UI connections, never egress.
          ip link add qbt-host type veth peer name qbt-ui netns ${namespace}
          ip address add 10.200.200.1/30 dev qbt-host
          ip -n ${namespace} address add 10.200.200.2/30 dev qbt-ui
          ip netns exec ${namespace} nft -f - <<'EOF'
          table inet qbt {
            chain input {
              type filter hook input priority 0; policy drop;
              meta nfproto ipv6 drop
              iifname "lo" accept
              ct state established,related accept
              iifname "qbt-ui" ip saddr 10.200.200.1 tcp dport 8080 accept
              iifname "qbt-wg" tcp dport 8080 drop
              iifname "qbt-wg" accept
            }
            chain output {
              type filter hook output priority 0; policy drop;
              meta nfproto ipv6 drop
              oifname "lo" accept
              oifname "qbt-wg" accept
              oifname "qbt-ui" ip daddr 10.200.200.1 tcp sport 8080 ct state established accept
            }
            chain forward {
              type filter hook forward priority 0; policy drop;
            }
          }
          EOF
          ip link set qbt-host up
          ip -n ${namespace} link set qbt-ui up
        '';
        # ExecStopPost also cleans up a partially failed startup.
        postStop = ''
          ip link del qbt-host 2>/dev/null || true
          ip -n ${namespace} link del qbt-wg 2>/dev/null || true
          ip link del qbt-wg 2>/dev/null || true
          ip netns del ${namespace} 2>/dev/null || true
        '';
      };
      qbittorrent = {
        requires = ["qbittorrent-vpn.service"];
        after = ["qbittorrent-vpn.service"];
        bindsTo = ["qbittorrent-vpn.service"];
        partOf = ["qbittorrent-vpn.service"];
        unitConfig.RequiresMountsFor = ["/mnt/hdd_storage_01"];
        preStart = ''
          mkdir -p ${downloads}
          ${pkgs.python3}/bin/python3 ${helper} configure ${config.services.qbittorrent.profileDir}/qBittorrent/config/qBittorrent.conf ${downloads}
        '';
        serviceConfig = {
          NetworkNamespacePath = "/run/netns/${namespace}";
          BindReadOnlyPaths = ["${resolver}:/etc/resolv.conf"];
          UMask = "0002";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
      qbittorrent-port-forward = {
        description = "Renew Proton NAT-PMP leases and update qBittorrent's listening port";
        wantedBy = ["multi-user.target"];
        requires = ["qbittorrent.service" "qbittorrent-vpn.service"];
        after = ["qbittorrent.service" "qbittorrent-vpn.service"];
        bindsTo = ["qbittorrent-vpn.service"];
        partOf = ["qbittorrent-vpn.service"];
        path = [pkgs.libnatpmp];
        serviceConfig = {
          ExecStart = "${pkgs.python3}/bin/python3 ${helper} forward";
          NetworkNamespacePath = "/run/netns/${namespace}";
          BindReadOnlyPaths = ["${resolver}:/etc/resolv.conf"];
          DynamicUser = true;
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          CapabilityBoundingSet = "";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
  };
  services.nginx.virtualHosts."qbittorrent.internal.bliztle.com".locations."/" = {
    proxyPass = "http://10.200.200.2:8080";
    proxyWebsockets = true;
    extraConfig = ''
      allow 10.0.0.0/24;
      deny all;
    '';
  };
}
