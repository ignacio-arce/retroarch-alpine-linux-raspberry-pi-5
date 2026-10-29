#!/bin/sh
# install.sh - Instalación de dependencias y configuración de servicios

# 1. Actualizar repositorios
apk update

# 2. Instalar dependencias agrupadas bajo un paquete virtual
apk add --virtual retro-kiosk-deps \
    cage \
    retroarch \
    retroarch-assets \
    mesa-dri-gallium \
    mesa-egl \
    mesa-gles \
    seatd \
    eudev \
    alsa-utils \
    agetty \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    wireplumber

# 3. Habilitar demonios de hardware e input en OpenRC (arranque automático)
rc-update add udev sysinit
rc-update add udev-trigger sysinit
rc-update add seatd default

# 4. Iniciar los servicios en la sesión actual
rc-service udev start
rc-service udev-trigger start
rc-service seatd start

# 5. Añadir el usuario estándar a los grupos de hardware
# NOTA: Reemplaza "tu_usuario" por tu nombre de usuario real en Alpine
TARGET_USER="admin"
addgroup $TARGET_USER video
addgroup $TARGET_USER input
addgroup $TARGET_USER audio
addgroup $TARGET_USER seat

# 6. Auto-login en tty1 con agetty (https://wiki.alpinelinux.org/wiki/TTY_Autologin)
# Se borra la línea tty1 existente y se añade la nueva para no depender del formato exacto.
# Si agetty no se instaló, no se toca /etc/inittab (se conserva el getty por defecto de busybox).
if command -v agetty >/dev/null 2>&1; then
    sed -i '/^tty1::/d' /etc/inittab
    echo "tty1::respawn:/sbin/agetty --autologin $TARGET_USER tty1 linux" >> /etc/inittab
fi

# 7. Auto-arrancar el kiosk desde .profile, solo cuando la sesión es tty1.
# Si cage/RetroArch termina, el shell muere, agetty hace respawn y se relanza solo.
START_SCRIPT="$(cd "$(dirname "$0")" && pwd)/start.sh"
PROFILE="/home/$TARGET_USER/.profile"
if ! grep -q "kiosk-retroarch" "$PROFILE" 2>/dev/null; then
    cat >> "$PROFILE" <<EOF
# kiosk-retroarch: arranque automático de RetroArch en tty1 (install.sh)
[ "\$(tty)" = "/dev/tty1" ] && exec $START_SCRIPT # kiosk-retroarch
EOF
fi
chown $TARGET_USER:$TARGET_USER "$PROFILE"

echo "Instalación completada. REINICIA el equipo para aplicar el autologin (agetty) y los cambios de grupos."
