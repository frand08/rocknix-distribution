# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2025 ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="ap6275p-firmware"
PKG_VERSION="1d1d4ac234c23ea7d7dc85a001492f7e0e765f80"
PKG_LICENSE="Apache"
PKG_SITE="https://github.com/armbian/firmware"
PKG_URL="${PKG_SITE}/archive/${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="AP6275P PCIe WiFi+BT (Orange Pi 5B) Linux firmware"
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/$(get_kernel_overlay_dir)/lib/firmware/brcm

  # PCIe WiFi firmware for AP6275P (BCM43752 / PCI ID 14E4:449D)
  # Chip is BCM43752A2; driver requests brcmfmac43752-pcie.* not brcmfmac43711-pcie.*
  for f in brcmfmac43752-pcie.bin brcmfmac43752-pcie.clm_blob brcmfmac43752-pcie.txt; do
    [ -f brcm/${f} ] && cp -av brcm/${f} ${INSTALL}/$(get_kernel_overlay_dir)/lib/firmware/brcm/ || true
  done

  # BT firmware (UART HCI, used by ap6611s autostart script)
  [ -f brcm/SYN43711A0.hcd ] && cp -av brcm/SYN43711A0.hcd ${INSTALL}/$(get_kernel_overlay_dir)/lib/firmware/brcm/ || true
}
