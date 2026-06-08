#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

# Save WAYLAND_DISPLAY before /etc/profile overwrites it.
_WD_SAVE="${WAYLAND_DISPLAY}"
. /etc/profile
set_kill set "-9 eden-sa"

# Probe for the real Wayland socket.
_XDG="${XDG_RUNTIME_DIR:-/var/run/0-runtime-dir}"
for _WD in "${_WD_SAVE}" "wayland-1" "wayland-0" "wayland-2"; do
  [ -n "${_WD}" ] && [ -S "${_XDG}/${_WD}" ] && { export WAYLAND_DISPLAY="${_WD}"; break; }
done
export XDG_RUNTIME_DIR="${_XDG}"

# On RK3588 with libmali, gpudriver bind-mounts /dev/null over libGL.so at boot.
# Eden creates a GL context for its GUI even when rendering via Vulkan, so this
# must be restored or Eden fails with "Unable to create main openGL context".
_LIBGL_REAL=$(readlink -f /usr/lib/libGL.so 2>/dev/null)
[ -n "${_LIBGL_REAL}" ] && umount "${_LIBGL_REAL}" 2>/dev/null || true
umount /usr/lib/libGL.so 2>/dev/null || true

GAME="${1}"
PLATFORM="${2}"
ROMNAME=$(echo "${GAME}" | sed "s#^/.*/##")

# Seed default config on first run.
if [ ! -d "/storage/.config/eden" ]; then
  mkdir -p "/storage/.config/eden"
  cp -r "/usr/config/eden/." "/storage/.config/eden/" 2>/dev/null
fi
if [ ! -f "/storage/.config/eden/qt-config.ini" ] && [ -f "/usr/config/eden/qt-config.ini" ]; then
  cp "/usr/config/eden/qt-config.ini" "/storage/.config/eden/qt-config.ini"
fi

# eden reads data from ~/.local/share/eden; keep config and data unified.
mkdir -p "/storage/.local/share/eden/keys"
mkdir -p "/storage/.local/share/eden/nand"

# Link keys from the bios directory if present.
if [ -d "/storage/roms/bios/switch/keys" ]; then
  for key in /storage/roms/bios/switch/keys/*.keys; do
    [ -f "$key" ] && ln -sf "$key" "/storage/.local/share/eden/keys/$(basename "$key")" 2>/dev/null
  done
fi

# CPU affinity
CORES=$(get_setting "cores" "${PLATFORM}" "${ROMNAME}")
if [ "${CORES}" = "little" ]; then
  EMUPERF="${SLOW_CORES}"
elif [ "${CORES}" = "big" ]; then
  EMUPERF="${FAST_CORES}"
else
  unset EMUPERF
fi

export QT_QPA_PLATFORM=wayland
export SDL_AUDIODRIVER=pulseaudio

# Launch (-f forces fullscreen)
if [ -n "${GAME}" ]; then
  ${EMUPERF} /usr/bin/eden-sa -f -g "${GAME}" >/var/log/eden.log 2>&1
else
  ${EMUPERF} /usr/bin/eden-sa >/var/log/eden.log 2>&1
fi
