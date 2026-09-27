"""Non-secret qBittorrent settings and Proton's renewable NAT-PMP lease."""

import configparser
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request


def configure(filename, downloads):
    config = configparser.RawConfigParser()
    config.optionxform = str
    config.read(filename)
    for section in ("Preferences", "BitTorrent"):
        if not config.has_section(section):
            config.add_section(section)
    # Preserve user settings and passwords; enforce only isolation/API settings.
    for key, value in {
        "WebUI\\Address": "*",
        "WebUI\\LocalHostAuth": "false",
        "WebUI\\AuthSubnetWhitelistEnabled": "false",
        "WebUI\\HostHeaderValidation": "true",
        "WebUI\\ServerDomains": "qbittorrent.internal.bliztle.com;localhost;127.0.0.1",
        "Connection\\UPnP": "false",
    }.items():
        config.set("Preferences", key, value)
    for key, value in {
        "Session\\Interface": "qbt-wg",
        "Session\\InterfaceName": "qbt-wg",
        "Session\\UPnP": "false",
    }.items():
        config.set("BitTorrent", key, value)
    if not config.has_option("BitTorrent", "Session\\DefaultSavePath"):
        config.set("BitTorrent", "Session\\DefaultSavePath", downloads)
    target = Path(filename)
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(".tmp")
    with temporary.open("w") as output:
        os.chmod(temporary, 0o600)
        config.write(output, space_around_delimiters=False)
    temporary.replace(target)


def mapped_port(output):
    match = re.search(r"Mapped public port (\d+) protocol", output)
    if not match or not 1 <= int(match[1]) <= 65535:
        raise ValueError("NAT-PMP did not return a valid public port")
    return int(match[1])


def mapping(protocol):
    result = subprocess.run(
        ["natpmpc", "-a", "1", "0", protocol, "60", "-g", "10.2.0.1"],
        check=True, capture_output=True, text=True, timeout=10,
    )
    return mapped_port(result.stdout)


def forward():
    # No host proxy or credentials: only loopback inside the isolated namespace
    # bypasses authentication. nginx connects over the veth and requires login.
    client = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    previous = None
    while True:
        try:
            udp = mapping("udp")
            tcp = mapping("tcp")
            if udp != tcp:
                raise ValueError("Proton returned different TCP and UDP ports")
            payload = urllib.parse.urlencode({
                "json": json.dumps({"listen_port": tcp, "upnp": False, "random_port": False})
            }).encode()
            request = urllib.request.Request(
                "http://127.0.0.1:8080/api/v2/app/setPreferences",
                data=payload, headers={"Referer": "http://127.0.0.1:8080/"},
            )
            with client.open(request, timeout=5) as response:
                response.read()
            if previous != tcp:
                print(f"Proton forwarded TCP/UDP port {tcp}", flush=True)
                previous = tcp
            time.sleep(40)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            print(f"Port forwarding unavailable; retrying: {error}", flush=True)
            time.sleep(5)


if __name__ == "__main__":
    if sys.argv[1] == "configure":
        configure(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == "forward":
        forward()
