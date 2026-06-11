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

# Apply EmulationStation per-system graphics settings to Eden's qt-config.ini.
# IMPORTANT: Eden ignores any value whose "<key>\default" flag is true, so we
# must clear that flag in addition to writing the value. Empty settings (option
# left unset in ES) are skipped so Eden keeps its own defaults.
EDEN_CONF="/storage/.config/eden/qt-config.ini"
eden_set() {
  # $1 = ini key, $2 = value
  [ -z "${2}" ] && return 0
  [ -f "${EDEN_CONF}" ] || return 0
  if grep -q "^${1}=" "${EDEN_CONF}"; then
    sed -i "s~^${1}=.*~${1}=${2}~" "${EDEN_CONF}"
  else
    sed -i "/^\[Renderer\]/a ${1}=${2}" "${EDEN_CONF}"
  fi
  if grep -q "^${1}\\\\default=" "${EDEN_CONF}"; then
    sed -i "s~^${1}\\\\default=.*~${1}\\\\default=false~" "${EDEN_CONF}"
  else
    sed -i "/^\[Renderer\]/a ${1}\\\\default=false" "${EDEN_CONF}"
  fi
}

eden_set resolution_setup          "$(get_setting resolution_scale        "${PLATFORM}" "${ROMNAME}")"
eden_set gpu_accuracy              "$(get_setting gpu_accuracy             "${PLATFORM}" "${ROMNAME}")"
eden_set use_asynchronous_shaders  "$(get_setting async_shaders           "${PLATFORM}" "${ROMNAME}")"
eden_set use_vsync                 "$(get_setting vsync                   "${PLATFORM}" "${ROMNAME}")"
eden_set max_anisotropy            "$(get_setting anisotropic_filtering   "${PLATFORM}" "${ROMNAME}")"
eden_set scaling_filter            "$(get_setting scaling_filter          "${PLATFORM}" "${ROMNAME}")"

export QT_QPA_PLATFORM=wayland
export SDL_AUDIODRIVER=pulseaudio

# Launch (-f forces fullscreen)
if [ -n "${GAME}" ]; then
  ${EMUPERF} /usr/bin/eden-sa -f -g "${GAME}" >/var/log/eden.log 2>&1
else
  ${EMUPERF} /usr/bin/eden-sa >/var/log/eden.log 2>&1
fi
