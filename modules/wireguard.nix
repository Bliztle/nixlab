{
  lib,
  meta,
  ...
}:
{
  # networking.wg-quick.interfaces.wg-mullvad-dk = lib.mkIf (meta.hostname == "homelab-zenbook") {
  #   autostart = false;
  #   privateKeyFile = "/run/secrets/wg_zenbook_mullvad_dk_private";
  #   address = [
  #     "10.71.60.4/32"
  #     "fc00:bbbb:bbbb:bb01::8:3c03/128"
  #   ];
  #   dns = [ "10.64.0.1" ];
  #   peers = [
  #     {
  #       publicKey = "Jjml2TSqKlgzW6UzPiJszaun743QYpyl5jQk8UOQYg0=";
  #       allowedIPs = [
  #         "0.0.0.0/0"
  #         "::/0"
  #       ];
  #       endpoint = "146.70.197.194:51820";
  #     }
  #   ];
  #   postUp = ''
  #     # Force wg with killswich
  #     # iptables -I OUTPUT ! -o wg-mullvad-dk -m mark ! --mark $(wg show wg-mullvad-dk fwmark) -m addrtype ! --dst-type LOCAL ! -d 10.0.0.0/8 -j REJECT
  #     # ip6tables -I OUTPUT ! -o wg-mullvad-dk -m mark ! --mark $(wg show wg-mullvad-dk fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
  #     # Allow established connections to continue
  #     # iptables -I OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  #     # ip6tables -I OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  #     # iptables -I OUTPUT -p tcp --sport 443 -j ACCEPT
  #     iptables -I OUTPUT ! -o wg-mullvad-dk -m mark ! --mark $(wg show wg-mullvad-dk fwmark) -m addrtype ! --dst-type LOCAL ! -d 10.0.0.0/8 ! -m conntrack --ctstate ESTABLISHED,RELATED -j REJECT
  #     ip6tables -I OUTPUT ! -o wg-mullvad-dk -m mark ! --mark $(wg show wg-mullvad-dk fwmark) -m addrtype ! --dst-type LOCAL ! -d 10.0.0.0/8 ! -m conntrack --ctstate ESTABLISHED,RELATED -j REJECT
  #   '';
  #
  #   preDown = ''
  #     # iptables -D OUTPUT ! -o wg-mullvad-dk -m mark ! --mark $(wg show wg-mullvad-dk fwmark) -m addrtype ! --dst-type LOCAL ! -d 10.0.0.0/8 -j REJECT
  #     # ip6tables -D OUTPUT ! -o wg-mullvad-dk -m mark ! --mark $(wg show wg-mullvad-dk fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
  #     # iptables -D OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  #     # ip6tables -D OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  #     # iptables -D OUTPUT -p tcp --sport 443 -j ACCEPT
  #     iptables -D OUTPUT ! -o wg-mullvad-dk -m mark ! --mark $(wg show wg-mullvad-dk fwmark) -m addrtype ! --dst-type LOCAL ! -d 10.0.0.0/8 ! -m conntrack --ctstate ESTABLISHED,RELATED -j REJECT
  #     ip6tables -D OUTPUT ! -o wg-mullvad-dk -m mark ! --mark $(wg show wg-mullvad-dk fwmark) -m addrtype ! --dst-type LOCAL ! -d 10.0.0.0/8 ! -m conntrack --ctstate ESTABLISHED,RELATED -j REJECT
  #   '';
  # };
}
