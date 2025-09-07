{ pkgs, ... }:
let
  iptables = "${pkgs.iptables}/bin/iptables";
in
{
  networking.nat.enable = true;
  networking.nat.externalInterface = "eth0";
  networking.nat.internalInterfaces = [ "wg0" ];
  networking.firewall.allowedUDPPorts = [ 53 51820 ]; # Open dns and wg

  # Enable ip forwarding, so unresolved packets are sent to the network
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  networking.wireguard.interfaces = {
    wg0 = {
      # Subnet
      ips = [ "10.100.0.1/24" ];
      listenPort = 51820; # TODO: Change this
      
      # This allows the wireguard server to route your traffic to the internet and hence be like a VPN
      # For this to work you have to set the dnsserver IP of your router (or dnsserver of choice) in your clients
      postSetup = ''
        # ${iptables} -t nat -A POSTROUTING -s 10.100.0.0/24 -o eth0 -j MASQUERADE
        ${iptables} -t nat -A POSTROUTING -s 10.100.0.0/24 -o end0 -j MASQUERADE
        # ${iptables} -A FORWARD -i wg0 -o eth0 -j ACCEPT
        ${iptables} -A FORWARD -i wg0 -o end0 -j ACCEPT
        # ${iptables} -A FORWARD -i wg0 -j ACCEPT
        # ${iptables} -A FORWARD -i eth0 -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT
        ${iptables} -A FORWARD -i end0 -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT
      '';
      
      # This undoes the above command
      postShutdown = ''
        # ${iptables} -t nat -D POSTROUTING -s 10.100.0.0/24 -o eth0 -j MASQUERADE
        # ${iptables} -D FORWARD -i wg0 -o eth0 -j ACCEPT
        # ${iptables} -D FORWARD -i eth0 -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT
        ${iptables} -t nat -D POSTROUTING -s 10.100.0.0/24 -o end0 -j MASQUERADE
        ${iptables} -D FORWARD -i wg0 -o end0 -j ACCEPT
        ${iptables} -D FORWARD -i end0 -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT
      '';

      # Check out sops nix
      privateKeyFile = "/run/secrets/wg0_pi_private";
      peers = [
        # List of allowed peers.
        { 
          # Zenbook
          publicKey = "LTXLpQNCoOqvVKXB4pzCbR6ggz3vDycx0/tvD1GYmzU=";
          # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
          allowedIPs = [ "10.100.0.2/32" ];
        }
        { 
          # Oneplus
          publicKey = "hVwlQV0SuM0AsMF65GgmgS8CUdxVkhfZMp3YR9kgcEc=";
          allowedIPs = [ "10.100.0.2/32" ];
        }
      ];
    };
  };
}
