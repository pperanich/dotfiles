# Protectli Support Ticket

## Subject

VP2440 MT7916AN/MT7915E WiFi 6 - Asymmetric TCP Performance (Download degraded, Upload clean)

## Description

I'm running a Protectli VP2440 (Intel N150 CPU) as a NixOS router with the included WiFi 6 card. Protectli documentation indicates this is an MT7916AN chipset, however Linux detects it as MT7915E. The WiFi is configured via hostapd in AP mode with both 2.4GHz and 5GHz radios active.

### The Problem

I'm experiencing severe asymmetric performance on the 5GHz radio:

- **Download (AP → Client):** ~244 Mbps with 1,700+ TCP retransmissions
- **Upload (Client → AP):** ~400 Mbps, clean (0 retries)

### Key Diagnostic Finding

The WiFi MAC layer reports perfect metrics (860+ Mbps TX rate, 0 MAC-layer retries) while the TCP layer simultaneously shows thousands of retransmissions. This suggests packets are being dropped or delayed somewhere between the driver TX path and the air interface.

### Ruled Out

- **Client bottleneck:** I tested my MacBook Pro connected to a separate access point, routing traffic through the VP2440 via ethernet - achieved 608 Mbps with only 6 retries. The same client connected directly to the VP2440's WiFi gets 244 Mbps with 1,700+ retries.
- Firewall/routing (tested with flow offload, MSS clamping, direct bridge)
- MU-BEAMFORMER (actually made performance worse - disabled)
- Channel selection (tested ACS and fixed channels)

### Attachments

I've attached a comprehensive debug package including system diagnostics, iperf3 results, hostapd config, and real-time station monitoring logs captured during the tests.
