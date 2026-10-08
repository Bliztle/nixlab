{pkgs, ...}: {
  users = {
    groups.teamtype = {};
    users.teamtype = {
      isSystemUser = true;
      group = "teamtype";
      home = "/var/lib/teamtype-specialization";
    };
  };

  systemd.services.teamtype-specialization = {
    description = "Teamtype permanent peer for uni/specialization";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];

    # Pre-create the metadata directory to avoid the first-run interactive prompt.
    # Only this unit owns the project; a crash can leave a stale editor socket.
    preStart = ''
      install -d -m 0700 /var/lib/teamtype-specialization/project/.teamtype
      rm -f /var/lib/teamtype-specialization/project/.teamtype/socket
    '';

    # Open the private log only after systemd has created StateDirectory.
    # StandardOutput=truncate: is opened too early on the first service start.
    # The persistent .teamtype/key keeps the invitation valid across restarts;
    # no one-time join codes or Magic Wormhole connection are needed.
    script = ''
      exec > /var/lib/teamtype-specialization/session.log 2>&1
      exec ${pkgs.teamtype}/bin/teamtype share --directory /var/lib/teamtype-specialization/project --username uni-specialization --no-join-code --show-secret-address
    '';

    serviceConfig = {
      User = "teamtype";
      Group = "teamtype";
      StateDirectory = "teamtype-specialization";
      StateDirectoryMode = "0700";
      WorkingDirectory = "/var/lib/teamtype-specialization";
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = "10s";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      RestrictSUIDSGID = true;
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
    };
  };
}
