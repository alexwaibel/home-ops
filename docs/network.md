# Network Segmentation - Baseline Architecture

This document describes the **baseline** home network segmentation: a default-deny inter-VLAN
posture with a small, explicit set of allowed cross-VLAN flows. The goal of this baseline is
narrow and pragmatic - move from "VLANs exist but nothing is firewalled between them" to
"inter-VLAN traffic is denied by default, and the few flows that are actually needed are
allowed explicitly." It is deliberately not the final, maximally-segmented design; see
[Deferred / future work](#deferred--future-work) for what is intentionally left out.

## Design principles

- **Default-deny inter-VLAN.** The foundation is that traffic between VLANs is dropped unless a
  rule explicitly allows it. Each VLAN interface ends in an explicit, logged deny so anything
  not matched is both blocked and visible in the logs (which is how missed flows get found).
- **Trust is a gradient, applied asymmetrically.** Personal is the trusted plane and is allowed
  to *initiate* to most of the network; untrusted VLANs (IoT, Guest, Work, Media) are treated
  as potentially hostile and only get narrow pinholes *to specific published services*. Because
  the firewall is stateful, "Personal may initiate to X" already covers X's replies - no reverse
  rule is needed, which is what keeps the ruleset small instead of an N-by-N matrix.
- **Untrusted VLANs reach services, not peers.** IoT/Media/Guest/Work never get peer-to-peer
  access to each other. They reach one or two named services (the MQTT broker, Plex) plus the
  internet where appropriate, and nothing else internal.
- **A VLAN, not an IP address, is the trust boundary.** Firewall policy is written per-VLAN
  first. IP-based carve-outs inside a shared VLAN are a convenience, not an identity guarantee -
  any device on a VLAN can set its own IP/MAC.
- **Management access is gated even for Personal.** The switch/AP/router admin plane
  (`NET_MGMT`) is the keys to the kingdom and is not reachable from a general Personal device;
  it requires a WireGuard admin identity (or a small explicit admin-client alias), not mere
  network location.
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
| NVIDIA Shield                              | 7 Media      | Media/entertainment, casting + gamestream target |
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
- `NET_PRIVATE_V4` = 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 (all RFC1918, for default-deny rules)

**Host aliases:**

- `HOST_MQTT` = 192.168.20.80 (internal Envoy gateway terminating MQTT TLS)
- `HOST_PLEX` = 192.168.20.87
- `HOST_SAMSUNG_TV` = *(placeholder - static-reserve the TV's IP and fill in)*

**Port aliases:**

- `PORT_MQTT_TLS` = 8883 (Envoy MQTT TLS listener; 1883 is cluster-internal only)
- `PORT_PLEX` = 32400

MQTT clients on IoT VLANs reach `mosquitto.${SECRET_DOMAIN}` through `HOST_MQTT:8883`.
Envoy terminates TLS on the internal gateway and forwards the decrypted MQTT stream to the
cluster-internal `mosquitto` Service on port 1883.

## Home Assistant access

Home Assistant is reached over the internet through the Cloudflare tunnel, whose wildcard
ingress (`*.${SECRET_DOMAIN}`) terminates at the shared `envoy-external` Envoy gateway, which
routes `hass.${SECRET_DOMAIN}` to Home Assistant. HTTPS is terminated there. Home Assistant has
no dedicated LAN LoadBalancer IP in this baseline, so there is no inter-VLAN firewall rule for
reaching its dashboard directly - LAN clients use the same tunnel hostname.

## Per-VLAN firewall policy matrix

Default-deny inter-VLAN; explicit allow rules evaluated top-to-bottom per interface, with a
final logged deny on each interface. Each VLAN below lists only its allows; the trailing
deny-all is implied.

### VLAN 2 Personal (trusted plane)

Personal is allowed to *initiate* broadly; stateful returns cover the responses, so casting,
gamestream, NAS access, homelab access, and device app-remotes all work without per-service
reverse rules. The only subtraction is the management admin plane.

1. Allow `NET_PERSONAL -> this firewall` DNS(53)/DHCP(67-68)/NTP(123)
2. Block `NET_PERSONAL -> NET_MGMT` (management is via WireGuard identity, not from a general
   Personal device; if direct admin from Personal is wanted, allow a small admin-client alias
   here instead, not all of `NET_PERSONAL`)
3. Allow `NET_PERSONAL -> NET_PRIVATE_V4` any (the "allow-down" rule: Personal may initiate to
   Compute/homelab, NAS, Media for casting/gamestream, IoT, etc. See the trust note below.)
4. Allow `NET_PERSONAL -> WAN` any

> **Trust note:** rule 3 is a deliberate, pragmatic choice - Personal is where daily work
> happens, so it is allowed to reach the rest of the LAN and the firewall relies on stateful
> return traffic. The cost is that a compromised personal device can reach those internal
> destinations. Tightening Personal (splitting admin/daily devices, narrowing "allow-down" to
> named services) is deferred; see [Deferred / future work](#deferred--future-work).

### VLAN 7 Media

Media reaches Plex and the internet, and receives Personal-initiated casting/gamestream via
stateful return of Personal's rule 3. It never initiates to Personal or other untrusted VLANs.

1. Allow `NET_MEDIA -> this firewall` DNS/DHCP/NTP
2. Allow `NET_MEDIA -> HOST_PLEX:PORT_PLEX` (Media devices acting as Plex clients)
3. Per-host: Block `HOST_SAMSUNG_TV -> WAN` (order this above the general Media WAN-allow rule)
4. Block `NET_MEDIA -> NET_PRIVATE_V4` except rule 2 (log)
5. Allow `NET_MEDIA -> WAN` any (except per-host deny above)

### VLAN 3 IoT-Cloud

1. Allow `NET_IOT_CLOUD -> this firewall` DNS/DHCP/NTP
2. Allow `NET_IOT_CLOUD -> HOST_MQTT:PORT_MQTT_TLS` (TLS only, no plaintext 1883)
3. Block `NET_IOT_CLOUD -> NET_PRIVATE_V4` (log)
4. Allow `NET_IOT_CLOUD -> WAN` any (cloud-dependent devices need this)

### VLAN 6 IoT-Local

1. Allow `NET_IOT_LOCAL -> this firewall` DNS/DHCP/NTP
2. Allow `NET_IOT_LOCAL -> HOST_MQTT:PORT_MQTT_TLS`
3. Block `NET_IOT_LOCAL -> NET_PRIVATE_V4` (log)
4. Block `NET_IOT_LOCAL -> WAN` (LAN-only by design)

### VLAN 4 Guest / VLAN 5 Work

1. Allow `-> this firewall` DNS/DHCP/NTP
2. Block `-> NET_PRIVATE_V4` (log)
3. Allow `-> WAN` any

### VLAN 20 Compute

Compute *serves* Plex/HA/MQTT inbound via the allows in the matrices above (those are written on
the consuming interfaces). In this baseline it does not initiate cross-VLAN to endpoint devices;
Compute-initiated device access (e.g. Home Assistant reaching cast/ESPHome devices) is deferred -
see [Deferred / future work](#deferred--future-work).

1. Allow `NET_COMPUTE -> this firewall` DNS/DHCP/NTP
2. Block `NET_COMPUTE -> endpoint VLANs` (2,3,4,5,6,7,10) default-deny (log)
3. Allow `NET_COMPUTE -> WAN` any (updates/images)

### VLAN 10 Management

1. No inbound from any VLAN except WireGuard admin peers (and, if configured, a small
   admin-client alias from Personal).
2. Allow `NET_MGMT -> WAN` for firmware/update checks only (or block entirely and update
   manually).

### VLAN 50 WireGuard

- Split-tunnel: per-peer `/32` allow rules to only the specific internal hosts/ports that peer
  needs (e.g. admin peer -> `NET_MGMT` + `NET_COMPUTE`; service peer -> a single host/port).
- Block `NET_WG -> NET_PRIVATE_V4` except the explicit per-peer allows above.

## mDNS reflection scope

Casting/AirPlay discovery is multicast and does not cross VLANs on its own, so even though the
firewall allows the Personal-initiated media flow, discovery needs a reflector:

- `os-mdns-repeater` (or equivalent) reflects mDNS **only between Personal and Media** - needed
  for casting/AirPlay discovery. No other VLAN pair gets mDNS reflection.
- Without this, casting will appear broken (targets don't show up) even though the firewall
  rules are correct - so treat the reflector as a required part of the baseline, not optional.

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
  - **Admin peers**: routed into `NET_WG`, with firewall rules granting Management + Compute
    access. Admin access uses WireGuard even from inside the house (no LAN-based admin bypass).
  - **Service peers**: routed into `NET_WG`, with firewall rules granting access to exactly one
    destination host/port.
- Split-tunnel by default; only home-network-destined traffic goes over the tunnel.
- An emergency physical Management port (a switch port hard-wired to `NET_MGMT`, physically
  accessible only to the owner) exists as an out-of-band recovery path if WireGuard/OPNsense
  configuration locks out remote admin access.

## Rollout guidance

Turning on default-deny for the first time will surface a handful of flows that were silently
relied on (a device phoning home, a cast target, a printer, NFS quirks). To limit blast radius:

1. Roll out VLAN-by-VLAN, starting with the untrusted VLANs (Guest, IoT) where a strict deny is
   safest and least likely to disrupt daily use.
2. Leave Personal for last, since its "allow-down" rule is the most permissive and least likely
   to break anything.
3. Watch the logged denies after each VLAN is switched over - they are the primary tool for
   finding a missed legitimate flow, which then becomes a new explicit allow.
4. Note that NFS in particular (Personal -> NAS) fails loudly and involves several ports;
   confirm it works after Personal is switched to default-deny.

## Validation / test plan per VLAN

For each VLAN, verify:

1. **Positive**: the explicit allow rules in the matrix above work (e.g. IoT-Local device can
   reach `HOST_MQTT:8883`, Media can reach Plex).
2. **Negative**: everything not explicitly allowed is blocked and logged (e.g. IoT-Cloud cannot
   reach Management or Compute, Guest cannot reach any RFC1918, Media cannot initiate to
   Personal).
3. **Cross-VLAN spoof test**: attempt to source traffic as an IP from a *different* VLAN's
   subnet. Success criterion: reverse-path filtering (pf `antispoof`, enabled by default in
   OPNsense) drops the packet at the ingress interface, and/or the switch's native-VLAN +
   disabled-auto-trunk configuration prevents the frame from ever reaching a different
   broadcast domain in the first place.

## Deferred / future work

The following are intentionally **out of scope** for this baseline and should be taken up
holistically once the baseline default-deny posture is live and stable:

- **Tightening Personal.** The "allow-down" rule is permissive by design for livability.
  Splitting admin vs. daily-driver devices, and narrowing Personal's internal reach to named
  services, is future work.
- **Compute-initiated cross-VLAN egress.** Home Assistant reaching cast/ESPHome/other devices on
  the IoT/Media VLANs (and similar cluster-initiated flows) is deliberately not enabled here. It
  is hard to do safely with the firewall alone: pod traffic leaves the cluster masqueraded
  behind a node IP, so any firewall rule allowing "the nodes -> device ports" would allow *every*
  pod on those nodes, not just the intended one.
- **Cluster-wide egress policy.** Closing the gap above properly needs a Kubernetes/Cilium
  egress baseline (default-deny egress with per-workload carve-outs, e.g. Plex -> Media,
  Home Assistant -> its devices). A per-pod policy on a single workload is not sufficient on its
  own, since it only constrains the pod it selects, not the others sharing the node IPs.
- **Service-VLAN separation.** Today VLAN 20 (Compute) mixes three roles: node egress source
  IPs, service ingress LoadBalancer VIPs, and infra hosts. Splitting the published-service VIPs
  onto their own VLAN would let inter-VLAN rules target services by subnet and shrink the node
  egress trust boundary. This churns the ingress path (Cilium IP pools, service annotations,
  external-dns, tunnel origin, OPNsense aliases) and deserves its own change.
