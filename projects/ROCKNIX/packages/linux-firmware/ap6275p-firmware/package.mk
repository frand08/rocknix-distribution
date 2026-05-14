# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2025 ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="ap6275p-firmware"
PKG_VERSION="9912b9a116e0073327fdc76d08660dcbab22442b"
PKG_LICENSE="Apache"
PKG_SITE="https://github.com/armbian/firmware"
PKG_URL="${PKG_SITE}/archive/${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="AP6275P PCIe WiFi+BT (Orange Pi 5B) Linux firmware"
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/$(get_kernel_overlay_dir)/lib/firmware/brcm

  # PCIe WiFi firmware (brcmfmac43711-pcie) for AP6275P
  # These files may also be present in the kernel-firmware package; installing
  # here ensures they are available even if the generic cleanup removes them.
  for f in brcmfmac43711-pcie.bin brcmfmac43711-pcie.clm_blob brcmfmac43711-pcie.txt; do
    [ -f brcm/${f} ] && cp -av brcm/${f} ${INSTALL}/$(get_kernel_overlay_dir)/lib/firmware/brcm/ || true
  done

  # Device-specific NVRAM for Orange Pi 5B (AP6275P on PCIe)
  # Named per the kernel firmware lookup order:
  #   brcmfmac43711-pcie.<dt-compatible>.txt
  for nvram in brcm/brcmfmac43711-pcie.orangepi,orangepi-5b.txt \
               brcm/brcmfmac43711-pcie.rockchip,rk3588s-orangepi-5b.txt; do
    [ -f ${nvram} ] && cp -av ${nvram} ${INSTALL}/$(get_kernel_overlay_dir)/lib/firmware/brcm/ || true
  done
}
