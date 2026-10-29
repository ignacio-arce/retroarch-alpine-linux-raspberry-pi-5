#!/bin/sh
# uninstall.sh - Desinstalación de dependencias y configuración de servicios
# Inverso de install.sh. NO borra la configuración ni los datos de RetroArch.

# 1. Detener servicios de hardware e input
rc-service seatd stop
rc-service udev-trigger stop
rc-service udev stop

# 2. Deshabilitar los servicios en OpenRC (arranque automático)
rc-update del seatd default
rc-update del udev-trigger sysinit
rc-update del udev sysinit

# 3. Eliminar dependencias agrupadas bajo el paquete virtual
apk del retro-kiosk-deps

# 4. Eliminar el stack de audio por si se instaló fuera del grupo virtual
apk del pipewire pipewire-alsa pipewire-pulse wireplumber

# 5. Quitar el usuario estándar de los grupos de hardware
# NOTA: Debe coincidir con TARGET_USER de install.sh
TARGET_USER="admin"
delgroup $TARGET_USER video
delgroup $TARGET_USER input
delgroup $TARGET_USER audio
delgroup $TARGET_USER seat

echo "Desinstalación completada. Por favor, CIERRA SESIÓN y vuelve a entrar para aplicar los cambios de grupos."
