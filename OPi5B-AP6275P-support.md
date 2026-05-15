# Orange Pi 5B WiFi + Bluetooth Support in ROCKNIX

## Hardware

- **Board**: Orange Pi 5B (RK3588S SoC)
- **WiFi chip**: BCM43752A2 (PCIe, PCI ID 14E4:449D), module AP6275P by AMPAK
- **BT chip**: BCM4362A2 (UART /dev/ttyS9), same silicon as WiFi combo chip
- **Driver**: `brcmfmac` (WiFi), `btbcm` (BT via `btattach`)
- **Kernel**: Armbian BSP 6.1.75 (RK3588 target in ROCKNIX)

---

## Problem 1: WiFi — scan returning empty / error -52

### Root cause

BCM43752A2 firmware (version 18.35.x, 2021) requires scan parameters in **v2 format**
(`BRCMF_ESCAN_REQ_VERSION_V2 = 2`). The BSP 6.1 kernel only sends v1, causing the
firmware to return `BCME_IE_NOTFOUND (-52)`, which blocks all WiFi scanning.

### Fix

New kernel patch backporting upstream scan params v2 support:

**File**: `projects/ROCKNIX/packages/linux/patches/RK3588/0002-brcmfmac-add-scan-params-v2-for-BCM43752A2.patch`

Changes across 4 kernel source files:
- `fwil_types.h`: Add `struct brcmf_scan_params_v2_le`, constants `BRCMF_SCAN_PARAMS_V2_FIXED_SIZE`,
  `BRCMF_SCAN_PARAMS_VERSION_V2`, `BRCMF_ESCAN_REQ_VERSION_V2`. Modify `brcmf_escan_params_le`
  to use a union with both v1 and v2 param structs.
- `feature.h`: Add `BRCMF_FEAT_SCAN_V2` feature flag.
- `feature.c`: Detect v2 support via `scan_ver` iovar at probe time.
- `cfg80211.c`: Always prepare v2 params in `brcmf_escan_prep()`. In `brcmf_run_escan()`,
  downgrade to v1 if `BRCMF_FEAT_SCAN_V2` is not set (older firmware compatibility).

### WiFi firmware

**File**: `projects/ROCKNIX/packages/linux-firmware/ap6275p-firmware/package.mk`

- Firmware source: Armbian firmware repo (`github.com/armbian/firmware`)
- WiFi firmware: `ap6275p/fw_bcm43752a2_pcie_ag.bin` → `brcmfmac43752-pcie.bin`
- CLM blob: `ap6275p/clm_bcm43752a2_pcie_ag.blob` → `brcmfmac43752-pcie.clm_blob`
- NVRAM: `ap6275p/nvram_ap6275p.txt` → `brcmfmac43752-pcie.txt`
- Used `cp -Lv` (not `cp -av`) to dereference symlinks in the Armbian firmware repo

---

## Problem 2: Bluetooth — chip not initializing on boot

### Root cause (firmware)

The `ap6275p-firmware` package was installing `SYN43711A0.hcd` (9KB) as the BT firmware.
That file is for the **AP6611S** chip (OPi 5 Max/Ultra), not the AP6275P.

The OPi 5B's BT chip self-identifies as **BCM4362A2** and requires `BCM4362A2.hcd` (80KB),
which is also in the Armbian firmware repo under `ap6275p/BCM4362A2.hcd`.

Symptoms of wrong firmware:
- `hciattach`: "Patch not found, continue anyway" (because hciattach looks in `/lib/firmware/`
  directly, not `/lib/firmware/brcm/`, and neither path had a matching filename)
- `btattach`: firmware uploads but chip fails to reset ("BCM: Reset failed -110") because
  the 9KB SYN43711A0.hcd binary is incompatible with the BCM4362A2 silicon

### Fix

**File**: `projects/ROCKNIX/packages/linux-firmware/ap6275p-firmware/package.mk`

```bash
# Changed from:
[ -f brcm/SYN43711A0.hcd ] && cp -Lv brcm/SYN43711A0.hcd ...

# Changed to:
[ -f ap6275p/BCM4362A2.hcd ] && cp -Lv ap6275p/BCM4362A2.hcd ...
```

### Root cause (service)

The `ap6611s` package provides the BT init service for OPi 5 Max/Ultra/5B.
Its `package.mk` was missing the installation of both the systemd service and the
autostart script. The service file itself had three bugs:
1. Hardcoded UART `/dev/ttyS7` (OPi 5B uses `/dev/ttyS9`)
2. Used `brcm_patchram_plus_rk3399` which gets stuck sending HCI resets on this chip
3. `hciconfig` path was `/usr/sbin/hciconfig` but binary is at `/usr/bin/hciconfig`

Additionally, `hciattach` cannot load firmware from `/lib/firmware/brcm/` (only from
`/lib/firmware/` directly). Switching to `btattach` uses the kernel's `btbcm` module
which correctly loads from `/lib/firmware/brcm/BCM4362A2.hcd`.

### Fixes

**File**: `projects/ROCKNIX/packages/network/ap6611s/package.mk`

Added to `makeinstall_target()`:
```bash
mkdir -p ${INSTALL}/usr/lib/systemd/system
cp ${PKG_DIR}/system.d/ap6611s-bluetooth.service ${INSTALL}/usr/lib/systemd/system/

mkdir -p ${INSTALL}/usr/lib/autostart/common
cp ${PKG_DIR}/autostart/008-ap6611s ${INSTALL}/usr/lib/autostart/common/
chmod 0755 ${INSTALL}/usr/lib/autostart/common/008-ap6611s
```

**File**: `projects/ROCKNIX/packages/network/ap6611s/system.d/ap6611s-bluetooth.service`

```ini
[Unit]
Description=Bluetooth OPi5 Max/Ultra/5B
After=bluetooth.target

[Service]
Type=simple
ExecStartPre=/usr/sbin/rfkill block bluetooth
ExecStartPre=/usr/bin/sleep 1
ExecStartPre=/usr/sbin/rfkill unblock bluetooth
ExecStartPre=/usr/bin/sleep 1
ExecStart=/bin/sh -c 'MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d "\0"); case "$MODEL" in *"5B"*) UART=/dev/ttyS9 ;; *) UART=/dev/ttyS7 ;; esac; exec /usr/bin/btattach -B $UART -P bcm -S 1500000'
ExecStartPost=/usr/bin/sleep 5
ExecStartPost=/usr/bin/hciconfig hci0 up
TimeoutSec=60
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Key changes:
- `Type=forking` → `Type=simple` (`btattach` stays in foreground)
- `hciattach bcm43xx` → `btattach -P bcm` (kernel handles firmware loading)
- UART auto-detected from `/proc/device-tree/model`: OPi 5B → `/dev/ttyS9`, others → `/dev/ttyS7`
- rfkill block/unblock cycle required before attach (chip does not initialize without it)
- 5s post-start delay to allow firmware upload and chip reset to complete
- `TimeoutSec` raised to 60s (firmware + reset can take ~10s)

---

## How it was diagnosed

### WiFi scan failure
```
brcmf_run_escan: error (-52)
```
Identified as `BCME_IE_NOTFOUND`. Found that BCM43752A2 firmware changelog (Oct 2021)
added v2 scan params requirement. Backported scan params v2 from upstream kernel.

### BT firmware mismatch
```
Bluetooth: hci0: BCM: firmware Patch file not found, tried:
Bluetooth: hci0: BCM: 'brcm/BCM4362A2.hcd'
```
Used `btattach` + `dmesg` to see exactly what filename the kernel's `btbcm` driver
was looking for. Identified chip as BCM4362A2. Confirmed `SYN43711A0.hcd` (9KB) was
wrong; `BCM4362A2.hcd` (80KB) was already in the Armbian firmware repo under `ap6275p/`.

### BT UART identification
```
ttyS9 at MMIO 0xfebc0000 (irq = ...) is a 16550A
[BT_RFKILL]: bt turn on power
```
`dmesg` showed ttyS9 is the BT UART on OPi 5B. Confirmed with successful
`hciattach /dev/ttyS9 bcm43xx 1500000`.

---

## Build and flash

```bash
cd ~/rocknix

# Full incremental build
make RK3588

# Produce flashable image
make mkimage RK3588

# Flash to SD card (replace sdX)
sudo umount /dev/sdX* 2>/dev/null
gunzip -c target/ROCKNIX-RK3588.aarch64-*.img.gz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

## Verification after boot

```bash
# BT service status
systemctl status ap6611s-bluetooth

# BT adapter info (should show BCM43752A2 UART ... build 1017)
hciconfig -a

# Scan for classic BT devices
hcitool scan

# Scan for BLE devices
hcitool lescan
```
