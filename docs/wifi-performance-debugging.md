# WiFi Performance Debugging: MT7915E Asymmetric Throughput Issue

## Problem Statement

**Hardware:** Protectli VP2440 router with Intel N150 CPU and MT7915E DBDC WiFi 6 card (2x2 MIMO)

**Symptom:** Severe asymmetric WiFi performance on 5GHz:

- **Download (AP to Client):** ~100-300 Mbps with 1000-6000 TCP retransmissions
- **Upload (Client to AP):** ~500-700 Mbps, clean

**The Paradox:** WiFi layer reports perfect conditions (1080-1200 Mbps TX rate, 0 MAC retries, 0 BA misses) while TCP sees massive retransmissions.

---

## Test Environment

### Network Topology

```
                                    ┌─────────────────────────────────┐
                                    │  New Router (pp-router1)        │
                                    │  Protectli VP2440               │
                                    │  Intel N150 + MT7915E           │
                                    │                                 │
┌──────────────┐                    │  WAN: 192.168.0.149 ◄───────────┼──── Old Router
│   MacBook    │◄─── 5GHz WiFi ────►│  LAN: 10.0.0.1 (br-lan)         │     192.168.0.1
│   (Client)   │     (wlan5)        │                                 │
│ 10.0.0.103   │                    │  WiFi: PP-Net (5GHz, 80MHz)     │
└──────────────┘                    └─────────────────────────────────┘
```

### Test Configuration

- **New Router (Under Test)**
  - IP (via old router): `192.168.0.149`
  - IP (production LAN): `10.0.0.1`
  - WiFi SSID: `PP-Net`
  - WiFi Band: 5GHz, 80MHz, ACS (auto channel)
  - WiFi Mode: 802.11ax (WiFi 6)
- **Old Router (Reference)**
  - IP: `192.168.0.1`
  - Used for comparison testing and as upstream during development

- **Test Client**
  - MacBook (Apple Silicon)
  - Broadcom WiFi chipset
  - IP on new router: `10.0.0.103`
  - IP on old router: `192.168.0.191`

### Test Methodology

**Primary Test (Download - AP to Client):**

```bash
# Client runs iperf3 in reverse mode (router sends to client)
iperf3 -c 10.0.0.1 -R -t 10
```

**Upload Test (Client to AP):**

```bash
# Client sends to router
iperf3 -c 10.0.0.1 -t 10
```

**UDP Test (Rule out TCP-specific issues):**

```bash
iperf3 -c 10.0.0.1 -R -u -b 800M -t 10
```

**Cross-Router Test (Isolate WiFi vs network stack):**

```bash
# Mac connected to OLD router WiFi, testing to new router
iperf3 -c 192.168.0.149 -R -t 10
```

### Deployment Process

Configuration changes are made in NixOS and deployed via:

```bash
clan machines update pp-router1 --target-host root@192.168.0.149
```

---

## Investigation Summary

### What We Tested and Ruled Out

| Component                | Test Performed                        | Result                         | Conclusion                        |
| ------------------------ | ------------------------------------- | ------------------------------ | --------------------------------- |
| **MU-MIMO Beamforming**  | Removed `MU-BEAMFORMER` from vhtCapab | No improvement                 | Not the cause                     |
| **All Beamforming**      | Disabled SU/MU beamforming            | Made it worse                  | Beamforming helps when it works   |
| **WiFi 6 (802.11ax)**    | Set `ieee80211ax = false`             | Worse (145 Mbps)               | WiFi 6 not the cause              |
| **Minimum TX Rates**     | Set `supported_rates` to 24+ Mbps     | Worse                          | Rate adaptation not primary issue |
| **nftables Firewall**    | Bypassed INPUT chain for br-lan       | No improvement                 | Firewall not the cause            |
| **Hardware Queues**      | Monitored PLE/PSE via debugfs         | No buildup (0xff9 free pages)  | Driver queues fine                |
| **mac80211 AQM**         | Checked fq_backlog, fq_overlimit      | All zeros                      | mac80211 not congested            |
| **BA (Block ACK)**       | Monitored BA miss count               | Always 0                       | No aggregation issues             |
| **AMSDU Packing**        | Checked tx_stats                      | 50% at 7 MSDUs, 24% at 8       | Efficient aggregation             |
| **Thermal Throttling**   | Checked thermal zones                 | 39-40C                         | Not thermal                       |
| **WED Hardware Offload** | Researched and verified               | Not available (Intel platform) | Expected, not an issue            |

---

## Key Diagnostic Findings

### 1. The 6 Mbps Legacy Rate Start (Partially Addressed)

**Discovery:** Initial connection starts at 6 Mbps legacy rate, then ramps up over ~5 seconds.

```
04:16:16  tx bitrate: 6.0 MBit/s          <- Legacy rate!
04:16:17  tx bitrate: 960.7 MBit/s        <- Jumped to proper rate
```

**Impact:** First 5 seconds of any transfer are slow. However, even after warmup, performance remains poor.

**Attempted Fix:** Set `supported_rates = "240 360 480 540"` - this prevented 6 Mbps start but overall performance was worse.

### 2. Perfect WiFi Layer, Broken TCP Layer

**The Core Mystery:**

| Layer    | Metric          | Value                      |
| -------- | --------------- | -------------------------- |
| WiFi MAC | TX bitrate      | 1080-1200 Mbps             |
| WiFi MAC | MAC retries     | 0                          |
| WiFi MAC | BA miss count   | 0                          |
| WiFi MAC | Signal          | -44 to -50 dBm (excellent) |
| TCP      | Throughput      | 100-300 Mbps               |
| TCP      | Retransmissions | 1000-6000 per 10s          |

The WiFi hardware believes packets are being delivered successfully, but TCP is retransmitting massively.

### 3. Erratic Performance Pattern

Typical download test shows:

```
0-1s:  300-500 Mbps (good start)
1-5s:  50-150 Mbps  (severe degradation)
5-8s:  30-70 Mbps   (worst)
8-10s: 200-600 Mbps (recovery)
```

This pattern is consistent across tests, suggesting a systematic issue rather than random interference.

### 4. UDP Also Affected

UDP test showed same pattern:

- First 6 seconds: 20-28% packet loss, 100-150 Mbps
- Last 3 seconds: 0% loss, 500+ Mbps

This rules out TCP-specific issues (congestion control, etc.).

### 5. TCP Congestion Control Test

Tested both Cubic (default) and BBR congestion control:

| Algorithm | Throughput | Retries | Analysis                    |
| --------- | ---------- | ------- | --------------------------- |
| Cubic     | ~150 Mbps  | ~1,500  | Backs off on packet loss    |
| BBR       | ~350 Mbps  | ~12,700 | Pushes through despite loss |

**Conclusion:** BBR achieves higher throughput by being aggressive, but the underlying packet loss is still present (actually worse). TCP congestion control is NOT the root cause.

### 6. Cross-Router Test (DEFINITIVE FINDING)

**Critical Test:** Same MacBook, but connected to OLD router's WiFi, testing against new router:

```bash
# Mac connected to OLD router WiFi, testing to new router
iperf3 -c 192.168.0.149 -R -t 10
```

| Test Path                                  | Throughput   | Retries      |
| ------------------------------------------ | ------------ | ------------ |
| New Router MT7915E WiFi → Mac              | 150-350 Mbps | 1,500-12,000 |
| Old Router WiFi → Wired → New Router → Mac | **608 Mbps** | **6**        |

**This definitively proves:**

- ✅ **MacBook is NOT the problem** - Works perfectly over old router WiFi
- ✅ **New router's TCP stack is NOT the problem** - Sends data fine over wired path
- ❌ **MT7915E WiFi radio is the problem** - Something specific to this chipset's TX path

---

## Root Cause Identification

Based on the cross-router test, the issue is **specifically the MT7915E WiFi transmitting to the MacBook**. The problem is NOT:

- The MacBook's WiFi/TCP stack
- The router's kernel/TCP stack
- The firewall or routing
- The bridge or queuing

The problem IS one of:

1. **MT7915E driver bug** (mt76 driver)
2. **MT7915E firmware bug**
3. **MT7915E + Apple Broadcom chipset incompatibility**
4. **Hostapd configuration issue specific to MT7915E**

---

## Tools and Commands Used

### WiFi Diagnostics

```bash
# Station info during transfer
iw dev wlan5 station dump

# Hardware queue status
cat /sys/kernel/debug/ieee80211/phy0/mt76/hw-queues

# TX statistics (BA miss, beamforming, AMSDU)
cat /sys/kernel/debug/ieee80211/phy0/mt76/tx_stats

# Firmware utilization
cat /sys/kernel/debug/ieee80211/phy0/mt76/fw_util_wm

# mac80211 AQM status
cat /sys/kernel/debug/ieee80211/phy0/aqm
```

### Network Stack

```bash
# Queue discipline
tc -s qdisc show dev wlan5

# Bridge stats
ip -s link show br-lan

# nftables tracing
nft monitor trace
```

### Performance Testing

```bash
# TCP download (AP to client)
iperf3 -c 10.0.0.1 -R -t 10

# TCP upload (client to AP)
iperf3 -c 10.0.0.1 -t 10

# UDP download
iperf3 -c 10.0.0.1 -R -u -b 800M -t 10
```

---

## Remaining Hypotheses

Based on the cross-router test proving the issue is MT7915E-specific:

### 1. MT7915E + Apple Broadcom Incompatibility (Most Likely)

**Theory:** The MT7915E has a specific incompatibility with Apple's Broadcom WiFi chipset, possibly related to:

- Block ACK handling
- AMPDU aggregation
- Power save negotiation
- Beamforming feedback (even with MU disabled)

**Evidence:**

- Same Mac works fine on old router WiFi
- Problem only occurs on MT7915E TX path
- Reports of similar issues in mt76 GitHub (Issue #980)

**Next Steps:**

- Test with non-Apple client to confirm Apple-specific
- Check mt76 GitHub for Apple compatibility patches
- Try different hostapd settings (disable AMPDU, adjust BA window)

### 2. MT7915E Driver Bug (mt76)

**Theory:** The mt76 driver has a bug in the TX path that causes packets to be reported as sent but not actually delivered.

**Evidence:**

- WiFi layer reports 0 MAC retries, 0 BA misses
- But packets clearly not reaching client (TCP retransmits)
- Driver queues show no buildup

**Next Steps:**

- Check for newer kernel with mt76 fixes
- Try different kernel version
- Enable firmware debug logging (`fw_debug_wm`)

### 3. PCIe/ASPM Issues

**Theory:** PCIe Active State Power Management is causing latency spikes or TX failures.

**Evidence:** Intel N150 + MT7915E PCIe combination is known to have ASPM issues.

**Test:**

```bash
# Check current ASPM
lspci -vv | grep -i aspm

# Disable at kernel level
# Add to boot params: pcie_aspm=off
```

### 4. Firmware Bug

**Theory:** MT7915 firmware has a bug affecting TX under certain conditions.

**Evidence:** Firmware version is from August 2024 (20240823).

**Next Steps:**

- Check for newer firmware
- Try older known-good firmware version
- Enable firmware debug logging

### ~~5. Client-Side Issue~~ (RULED OUT)

~~Theory: The Apple device has WiFi/TCP issues.~~

**Status:** RULED OUT by cross-router test. Same Mac works perfectly over old router WiFi.

### ~~6. TCP Congestion Control~~ (RULED OUT)

~~Theory: Congestion control mismatch.~~

**Status:** RULED OUT. Tested both Cubic and BBR - underlying packet loss exists regardless of algorithm.

---

## Configuration Changes Made

### Current hostapd.nix Changes

```nix
# 5GHz radio configuration
radio5 = {
  interface = wifi.radio5.name;
  band = "5GHz";
  channel = 0;  # ACS
  ieee80211ac = true;
  ieee80211ax = true;  # WiFi 6 enabled
  vhtOperChwidth = 1;  # 80MHz
  htCapab = "[LDPC][HT40+][HT40-][SHORT-GI-20][SHORT-GI-40][TX-STBC][RX-STBC1][MAX-AMSDU-7935]";
  # MU-BEAMFORMER removed due to Apple compatibility issues
  vhtCapab = "[RXLDPC][SHORT-GI-80][TX-STBC-2BY1][SU-BEAMFORMER][SU-BEAMFORMEE][RX-STBC-1][MAX-MPDU-11454][MAX-A-MPDU-LEN-EXP7]";
};
```

### Other Fixes Applied (Unrelated to This Issue)

1. **SAE/WPA3 Compatibility:** Changed `sae_pwe=1` to `sae_pwe=0` for Apple device compatibility
2. **DHCP Race Condition:** Added wait script for br-lan IP before Kea starts
3. **VLAN DHCP:** Added br-guest/br-iot to Kea interface list
4. **Flowtable Build:** Added `preCheckRuleset` workaround for nftables validation
5. **80MHz ACS:** Set `vht_oper_centr_freq_seg0_idx = 0` for ACS with 80MHz

---

## Recommended Next Steps

### Immediate Tests (Priority Order)

1. **Test with Non-Apple Client**
   - Use an Android phone, Windows laptop, or Linux device
   - If problem disappears → MT7915E + Apple Broadcom incompatibility
   - If problem persists → General MT7915E issue

2. **Disable PCIe ASPM**

   ```nix
   boot.kernelParams = [ "pcie_aspm=off" ];
   ```

   Known to cause issues with Intel N100/N150 + MT7915E.

3. **Try Fixed Channel (Non-DFS)**
   - Set `channel = 36` or `channel = 149`
   - Rule out ACS or DFS-related issues

### Driver/Firmware Experiments

4. **Enable Firmware Debug Logging**

   ```bash
   echo 1 > /sys/kernel/debug/ieee80211/phy0/mt76/fw_debug_wm
   dmesg -w | grep mt7915
   ```

   Monitor during iperf3 test to see firmware-level errors.

5. **Try Different Kernel Version**
   - Newer kernels may have mt76 fixes
   - Current: 6.12.67

6. **Check for Firmware Updates**
   - Current firmware: Build 20240823
   - Check linux-firmware repository for newer versions

### Hostapd Experiments

7. **Disable AMPDU Aggregation**
   Add to hostapd config:

   ```
   disable_11n_for_ap=1
   ```

   Or try smaller BA window sizes.

8. **Disable All Beamforming**
   Remove all `*BEAMFORM*` from vhtCapab and disable HE beamforming.

### Research Tasks

9. **Check mt76 GitHub Issues**
   - [Issue #980](https://github.com/openwrt/mt76/issues/980) - Download/Upload asymmetry
   - Search for Apple/Broadcom compatibility issues
   - Look for Intel N100/N150 + MT7915E reports

10. **OpenWrt Forums**
    - Search for similar MT7915E + Apple issues
    - Check for recommended hostapd settings

---

## Session Information

- **Date:** February 2, 2026
- **Router IP (testing):** 192.168.0.149
- **Router IP (production):** 10.0.0.1
- **Test Client:** MacBook (Apple Silicon) with Broadcom WiFi
- **Old Router:** Used for comparison testing (different WiFi chipset)
- **Kernel Version:** 6.12.67
- **MT7915 Firmware:** Build 20240823
- **Deploy Command:** `clan machines update pp-router1 --target-host root@192.168.0.149`

### Key Test Results Summary

| Test         | Path                        | Throughput   | Retries     | Conclusion            |
| ------------ | --------------------------- | ------------ | ----------- | --------------------- |
| Baseline     | MT7915E → Mac               | 150-300 Mbps | 1,500-6,000 | Broken                |
| BBR          | MT7915E → Mac               | 350 Mbps     | 12,700      | Masks but doesn't fix |
| Cross-router | Old WiFi → New Router → Mac | **608 Mbps** | **6**       | Mac is fine           |
| Upload       | Mac → MT7915E               | 500-700 Mbps | Clean       | TX to AP works        |

---

## References

- [mt76 GitHub Repository](https://github.com/openwrt/mt76)
- [Issue #980: Download/Upload Asymmetry](https://github.com/openwrt/mt76/issues/980)
- [MT7915 OpenWrt Performance Tuning](https://openwrt.org/docs/guide-user/network/wifi/mt76)
- [Linux Wireless Debugging](https://wireless.wiki.kernel.org/en/users/Documentation/iw)
