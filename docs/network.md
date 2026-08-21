# Network Segmentation - Target Architecture

This document describes the **target/desired state** of home network segmentation. It is a
design and runbook reference, not a vulnerability list - it intentionally does not enumerate
current gaps or unremediated weaknesses.

## Design principles

- **Assume endpoint compromise.** Every device on an untrusted VLAN (IoT, Guest, Work, Media)
  may be running unvetted firmware/software. Policy is written as if that device is hostile.
- **A VLAN, not an IP address, is the smallest trust boundary.** Firewall policy is written
  per-VLAN/subnet first. IP-based carve-outs inside a shared VLAN are a convenience, not an
  identity guarantee - any device on that VLAN can set its own IP/MAC.
- **Every member of an untrusted VLAN gets the same policy.** No "trust this one IoT device
  more" carve-outs within VLAN 3/4/5/6 - if a device needs broader access, it belongs in a
  different VLAN, not an exception rule.
- **IP aliases are used for destinations, not source authorization.** `HOST_*` aliases identify
  *where* traffic is allowed to go (e.g. `HOST_MQTT`); they are never used to grant a *source*
  extra privilege based on IP alone.
- **App-layer auth + TLS even when the firewall permits.** MQTT requires per-device credentials
  and ACLs, and TLS on 8883, even though the firewall already restricts IoT to
  `HOST_MQTT` only. Defense in depth: a compromised device on the correct VLAN with network
  access to the broker should still not be able to read/write other devices' topics.
- **Management access is via WireGuard identity**, not network location. Being physically on a
  VLAN does not grant Management access; a WireGuard peer identity does.
- **Per-host WAN-deny exceptions are acceptable.** Rules that only remove access (e.g. block a
  specific Samsung TV from reaching WAN) don't weaken the trust model, since they can only
  narrow what a device can do, never grant it more.

## Target VLAN table

| ID | Name         | Subnet            | Gateway        | DHCP range     | Notes                                   |
|----|--------------|-------------------|----------------|----------------|------------------------------------------|
| 1  | Parking      | 192.168.1.0/24    | 192.168.1.1    | 192.168.1.100+ | Native/unused VLAN, no real traffic      |
| 2  | Personal     | 192.168.2.0/24    | 192.168.2.1    | 192.168.2.100+ | Fully-controlled personal devices        |
| 3  | IoT-Cloud    | 192.168.3.0/24    | 192.168.3.1    | 192.168.3.100+ | Cloud-dependent IoT (WAN allowed)        |
| 4  | Guest        | 192.168.4.0/24    | 192.168.4.1    | 192.168.4.100+ | Internet-only, isolated                  |
| 5  | Work         | 192.168.5.0/24    | 192.168.5.1    | 192.168.5.100+ | Work laptop/phone, isolated from home    |
| 6  | IoT-Local    | 192.168.6.0/24    | 192.168.6.1    | 192.168.6.100+ | LAN-only IoT, no WAN                     |
| 7  | Media        | 192.168.7.0/24    | 192.168.7.1    | 192.168.7.100+ | Media/entertainment devices, incl. game consoles |
| 10 | Management   | 192.168.10.0/24   | 192.168.10.1   | 192.168.10.100+| Switch/AP/router admin plane             |
| 20 | Compute      | 192.168.20.0/24   | 192.168.20.1   | 192.168.20.100+| Homelab/k8s/NAS, low IPs = infra         |
| 50 | WireGuard    | 192.168.50.0/24   | 192.168.50.1   | n/a (per-peer) | Remote access, per-peer /32s             |

Low IPs (below the DHCP range) on each VLAN are reserved for static infrastructure (LB IPs,
radios, NAS, etc).

## Device-to-VLAN classification

| Device class                              | VLAN         | Rationale                                    |
|--------------------------------------------|--------------|-----------------------------------------------|
| Tasmota smart plugs                        | 6 IoT-Local  | No cloud dependency, LAN-only control via MQTT |
| ESPHome air purifier                       | 6 IoT-Local  | No cloud dependency, LAN-only via MQTT/API     |
| Robot vacuum (Valetudo)                    | 3 IoT-Cloud  | Needs WAN for maps/app companion features      |
| Denon AVR                                  | 7 Media      | Media/entertainment, casting target            |
| Samsung TV                                 | 7 Media      | Media/entertainment; WAN blocked per-host       |
| NVIDIA Shield                              | 7 Media      | Media/entertainment, casting target            |
| Game consoles (PlayStation/Xbox/Switch)     | 7 Media      | Media/entertainment, casting target            |
| Zigbee radio (192.168.20.184:6638)         | 20 Compute   | In-cluster serial-over-IP bridge for zigbee2mqtt|
| Z-Wave radio (192.168.20.183)              | 20 Compute   | In-cluster serial-over-IP bridge                |
| zigbee2mqtt / Home Assistant / Mosquitto   | 20 Compute   | Cluster-hosted infrastructure services          |
| Media-center (Plex host)                   | 20 Compute   | Cluster-hosted infrastructure service           |

## OPNsense aliases

**Network aliases** (one per VLAN subnet above):

- `NET_PARKING` = 192.168.1.0/24
- `NET_PERSONAL` = 192.168.2.0/24
- `NET_IOT_CLOUD` = 192.168.3.0/24
- `NET_GUEST` = 192.168.4.0/24
- `NET_WORK` = 192.168.5.0/24
- `NET_IOT_LOCAL` = 192.168.6.0/24
- `NET_MEDIA` = 192.168.7.0/24
- `NET_MGMT` = 192.168.10.0/24
- `NET_COMPUTE` = 192.168.20.0/24
- `NET_WG` = 192.168.50.0/24
- `NET_HOME` = union of all of the above (used for "block RFC1918 in general" rules)
- `NET_PRIVATE_V4` = 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 (all RFC1918, for default-deny rules)

**Host aliases:**

- `HOST_MQTT` = 192.168.20.85
- `HOST_MQTT_PORT` = 8883 (TLS listener only; 1883 is intra-cluster/VLAN-20 only, not routed)
- `HOST_HA_FRONTEND` = 192.168.20.91 (dedicated Envoy Gateway frontend, `envoy-ha`)
- `HOST_K8S_NODES` = 192.168.20.21, 192.168.20.22, 192.168.20.23 (the Talos nodes; used as the
  source for Home Assistant's cross-VLAN egress rules - see "Home Assistant cross-VLAN egress
  (Option D)" below for why this alias is deliberately coarse)
- `HOST_ZIGBEE_RADIO` = 192.168.20.184:6638
- `HOST_ZWAVE_RADIO` = 192.168.20.183
- `HOST_PLEX` = 192.168.20.87
- `HOST_SAMSUNG_TV` = *(placeholder - static-reserve the TV's IP and fill in)*

**Port aliases:**

- `PORT_MQTT_TLS` = 8883
- `PORT_HA` = 443 (HTTPS only, via `HOST_HA_FRONTEND`)
- `PORT_ESPHOME_API` = 6053 (optional, only if native API is used instead of MQTT)
- `PORT_CAST` = 8008-8009, 8443 (Google Cast control/discovery, HA-initiated only)

## Per-VLAN firewall policy matrix

Default-deny inter-VLAN; explicit allow rules evaluated top-to-bottom per interface.

### VLAN 3 IoT-Cloud
1. Allow `NET_IOT_CLOUD -> this firewall` DNS(53)/DHCP(67-68)/NTP(123)
2. Allow `NET_IOT_CLOUD -> HOST_MQTT:PORT_MQTT_TLS` (TLS only, no plaintext 1883)
3. Block `NET_IOT_CLOUD -> NET_PRIVATE_V4` (log)
4. Allow `NET_IOT_CLOUD -> WAN` any (cloud-dependent devices need this)

### VLAN 6 IoT-Local
1. Allow `NET_IOT_LOCAL -> this firewall` DNS/DHCP/NTP
2. Allow `NET_IOT_LOCAL -> HOST_MQTT:PORT_MQTT_TLS`
3. Block `NET_IOT_LOCAL -> NET_PRIVATE_V4` (log)
4. Block `NET_IOT_LOCAL -> WAN` (LAN-only by design)

### VLAN 7 Media
1. Allow `NET_MEDIA -> this firewall` DNS/DHCP/NTP
2. Allow `NET_PERSONAL -> NET_MEDIA` any (stateful, for casting initiation from Personal)
3. Allow `NET_MEDIA -> HOST_PLEX:32400` (if Plex clients live here)
4. Per-host: Block `HOST_SAMSUNG_TV -> WAN` (order this above the general Media WAN-allow rule)
5. Block `NET_MEDIA -> NET_PRIVATE_V4` except rule 3 (log)
6. Allow `NET_MEDIA -> WAN` any (except per-host deny above)

### VLAN 20 Compute
1. Allow `NET_COMPUTE -> this firewall` DNS/DHCP/NTP
2. Allow `HOST_K8S_NODES -> NET_MEDIA` `PORT_CAST` (Google Cast control; restricted to the
   Home Assistant pod by the in-cluster `CiliumNetworkPolicy`, not by this source alias)
3. Allow `HOST_K8S_NODES -> NET_IOT_LOCAL` `PORT_ESPHOME_API` (optional, only if native API used;
   same in-cluster restriction applies)
4. Block `NET_COMPUTE -> endpoint VLANs` (3,4,5,6,7) default-deny (log), except rules above
5. Allow `NET_COMPUTE -> WAN` any (updates/images)

### VLAN 2 Personal
1. Allow `NET_PERSONAL -> this firewall` DNS/DHCP/NTP
2. Allow admin clients (a small alias, not the whole `NET_PERSONAL`) `-> NET_MGMT`
3. Allow `NET_PERSONAL -> HOST_HA_FRONTEND:443`
4. Allow `NET_PERSONAL -> NET_MEDIA` (casting, see Media matrix rule 2)
5. Block `NET_PERSONAL -> NET_PRIVATE_V4` except rules above (log)
6. Allow `NET_PERSONAL -> WAN` any

### VLAN 4 Guest / VLAN 5 Work
1. Allow `-> this firewall` DNS/DHCP/NTP
2. Block `-> NET_PRIVATE_V4` (log)
3. Allow `-> WAN` any

### VLAN 10 Management
1. No inbound from any VLAN except explicit admin allow from Personal (rule above) and
   WireGuard admin peers.
2. Allow `NET_MGMT -> WAN` for firmware/update checks only (or block entirely and update
   manually).

### VLAN 50 WireGuard
- Split-tunnel: per-peer `/32` allow rules to only the specific internal hosts/ports that peer
  needs (e.g. admin peer -> `NET_MGMT` + `HOST_HA_FRONTEND`; service peer -> single host).
- Block `NET_WG -> NET_PRIVATE_V4` except the explicit per-peer allows above.

## Home Assistant cross-VLAN egress (Option D)

Most IoT integrations are MQTT-first, i.e. device -> broker *inbound*; the stateful reply covers
Home Assistant's side and no HA -> device rule is needed at all. Only the handful of
HA-initiated integrations (Google Cast, ESPHome native API, and similar) need cross-VLAN egress,
and those are handled in two layers:

1. **Coarse firewall layer**: OPNsense allows `HOST_K8S_NODES` (the Talos node IPs) to reach the
   specific device destinations + ports listed in the Compute matrix above. This is honest about
   what the firewall can actually see: pod traffic leaves the cluster masqueraded behind a node
   IP, so the firewall cannot distinguish Home Assistant from any other pod.
2. **Precise in-cluster layer**: the `home-assistant` `CiliumNetworkPolicy`
   (`kubernetes/apps/home-automation/home-assistant/app/networkpolicy.yaml`) selects the Home
   Assistant pod by label and puts it in default-deny egress, explicitly allowing in-cluster
   traffic, internet, and exactly those device destinations + ports. Because Cilium enforces on
   pod identity rather than IP, only Home Assistant can actually use the path the firewall rule
   opens - a compromised non-HA pod on the same node is dropped in-cluster.

The tradeoff is stated plainly: the firewall rule is broader than "only Home Assistant", and the
narrowing is done by Cilium. In exchange there is no single pinned egress IP, so no
single-node dependency or node-placement coupling for Home Assistant's egress path.

## mDNS reflection scope

- `os-mdns-repeater` (or equivalent) reflects mDNS **only between Personal and Media** - needed
  for casting/AirPlay discovery. No other VLAN pair gets mDNS reflection.
- Home Assistant's Google Cast integration should use a static `known_hosts`/IP entry for cast
  targets rather than relying on cross-VLAN mDNS discovery, since discovery traffic isn't
  reflected outside the Personal/Media pair.

## Wi-Fi model (UAP-AC-Pro)

The UAP-AC-Pro does not support PPSK, so per-device Wi-Fi identity is approximated with:

- One SSID per VLAN that has wireless clients (Personal, Guest, IoT-Cloud, IoT-Local, Work),
  each with its own PSK and VLAN tag.
- Client isolation enabled on Guest, IoT-Cloud, and IoT-Local SSIDs (devices on those SSIDs
  don't need to talk to each other; isolation removes same-VLAN ARP/discovery lateral movement
  as a bonus, on top of the VLAN boundary).
- Client isolation left off on Personal (needed for casting/AirPlay discovery, local file
  sharing, etc).

## Switch hardening (SG2016P v1.20)

- **Access ports**: end-device ports are explicitly configured as access ports pinned to a
  single VLAN (no tagged VLANs allowed).
- **Trunk ports**: only the OPNsense uplink and the AP uplink are trunks, carrying exactly the
  VLANs that need to reach that device.
- **Disable auto-trunk negotiation** (DTP-equivalent) on all ports to prevent switch-spoofing
  VLAN hopping attacks.
- **Native VLAN = Parking (1)** on all trunk ports, and Parking carries no real traffic, so a
  double-tagging attack lands in a dead-end VLAN.
- **Later-stage rollout** (raises attacker cost further, but does not by itself make IP/MAC a
  strong identity - it must be paired with the firewall matrix above):
  - DHCP snooping on all access ports.
  - Dynamic ARP Inspection using the DHCP snooping binding table.
  - IP Source Guard to block a host from using an IP it wasn't DHCP-assigned.

## WireGuard model

- Every peer gets its own `/32` allowed-IP on the WG interface - no shared peer keys.
- Two peer classes:
  - **Admin peers**: routed into `NET_WG`, with firewall rules granting Management + full
    Compute access. Admin access uses WireGuard even from inside the house (no LAN-based admin
    bypass).
  - **Service peers**: routed into `NET_WG`, with firewall rules granting access to exactly one
    destination host/port (e.g. remote access to `HOST_HA_FRONTEND:443` only).
- Split-tunnel by default; only home-network-destined traffic goes over the tunnel.
- An emergency physical Management port (a switch port hard-wired to `NET_MGMT`, physically
  accessible only to the owner) exists as an out-of-band recovery path if WireGuard/OPNsense
  configuration locks out remote admin access.

## Validation / test plan per VLAN

For each VLAN, verify:

1. **Positive**: the explicit allow rules in the matrix above work (e.g. IoT-Local device can
   reach `HOST_MQTT:8883`, Personal can reach `HOST_HA_FRONTEND:443`).
2. **Negative**: everything not explicitly allowed is blocked and logged (e.g. IoT-Cloud cannot
   reach Management, Guest cannot reach Compute).
3. **Spoofing test**: from a device on the VLAN, attempt to source traffic as another host's IP
   in the *same* carve-out (e.g. source traffic from a different Compute pod/host toward
   `NET_MEDIA` `PORT_CAST`, or spoof another IoT-Local device's IP). Success criterion: **even
   if the source spoof succeeds at the IP layer, the resulting traffic still only reaches the
   same narrow destination/port the real policy already allows** - i.e. spoofing gains the
   attacker no additional firewall privilege, because carve-outs are scoped to destination host
   + port, not granted based on trusting a source IP claim. For the Home Assistant egress
   carve-out specifically, this is defense in depth: the OPNsense rule is coarse (any node IP
   may reach those device ports), but the `home-assistant` `CiliumNetworkPolicy` means a
   non-Home-Assistant pod attempting to reach a device VLAN is dropped in-cluster by Cilium
   before the packet ever reaches the firewall.
4. **Cross-VLAN spoof test**: attempt to source traffic as an IP from a *different* VLAN's
   subnet. Success criterion: reverse-path filtering (pf `antispoof`, enabled by default in
   OPNsense) drops the packet at the ingress interface, and/or the switch's native-VLAN +
   disabled-auto-trunk configuration prevents the frame from ever reaching a different
   broadcast domain in the first place.
