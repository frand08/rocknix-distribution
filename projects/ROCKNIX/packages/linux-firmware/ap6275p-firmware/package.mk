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

  # PCIe WiFi firmware for AP6275P (BCM43752A2 / PCI ID 14E4:449D)
  # Use the AP6275P-specific firmware from ap6275p/ (not the generic brcm/ variants)
  [ -f ap6275p/fw_bcm43752a2_pcie_ag.bin ] && \
    cp -Lv ap6275p/fw_bcm43752a2_pcie_ag.bin \
    ${INSTALL}/$(get_kernel_overlay_dir)/lib/firmware/brcm/brcmfmac43752-pcie.bin || true
  [ -f ap6275p/clm_bcm43752a2_pcie_ag.blob ] && \
    cp -Lv ap6275p/clm_bcm43752a2_pcie_ag.blob \
    ${INSTALL}/$(get_kernel_overlay_dir)/lib/firmware/brcm/brcmfmac43752-pcie.clm_blob || true
  [ -f ap6275p/nvram_ap6275p.txt ] && \
    cp -Lv ap6275p/nvram_ap6275p.txt \
    ${INSTALL}/$(get_kernel_overlay_dir)/lib/firmware/brcm/brcmfmac43752-pcie.txt || true

  # BT firmware for BCM4362A2 (AP6275P UART BT, OPi 5B)
  [ -f ap6275p/BCM4362A2.hcd ] && cp -Lv ap6275p/BCM4362A2.hcd ${INSTALL}/$(get_kernel_overlay_dir)/lib/firmware/brcm/ || true
}
