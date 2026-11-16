#!/bin/sh
# uninstall.sh - Desinstalación de dependencias y configuración de servicios
# Inverso de install.sh. NO borra la configuración ni los datos de RetroArch.

TARGET_USER="admin"

# 1. Detener servicios de hardware e input
rc-service seatd stop
rc-service udev-trigger stop
rc-service udev stop

# 2. Deshabilitar los servicios en OpenRC (arranque automático)
rc-update del seatd default
rc-update del udev-trigger sysinit
rc-update del udev sysinit

# 3. Deshacer el autologin en tty1 y restaurar el getty por defecto de busybox.
# Ojo: esto debe ir ANTES de borrar agetty, o tty1 se quedaría sin getty.
sed -i '/^tty1::respawn:.*agetty --autologin/d' /etc/inittab
grep -q '^tty1::' /etc/inittab || echo 'tty1::respawn:/sbin/getty 38400 tty1' >> /etc/inittab

# 4. Quitar el auto-arranque del kiosk del .profile (líneas marcadas "kiosk-retroarch")
PROFILE="/home/$TARGET_USER/.profile"
if [ -f "$PROFILE" ]; then
    sed -i '/kiosk-retroarch/d' "$PROFILE"
    chown $TARGET_USER:$TARGET_USER "$PROFILE"
fi

# 5. Deshabilitar el repo testing de edge que añadió install.sh (cores libretro)
sed -i '/edge\/testing/d' /etc/apk/repositories

# 6. Eliminar dependencias agrupadas bajo el paquete virtual
apk del retro-kiosk-deps

# 7. Eliminar los cores de emulación (grupo virtual retro-cores)
apk del retro-cores

# 8. Eliminar el stack de audio por si se instaló fuera del grupo virtual
apk del pipewire pipewire-alsa pipewire-pulse wireplumber

# 9. Quitar el usuario estándar de los grupos de hardware
# NOTA: Debe coincidir con TARGET_USER de install.sh
delgroup $TARGET_USER video
delgroup $TARGET_USER input
delgroup $TARGET_USER audio
delgroup $TARGET_USER seat

echo "Desinstalación completada. REINICIA el equipo para aplicar los cambios de inittab y de grupos."
