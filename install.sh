#!/bin/sh
# install.sh - Instalación de dependencias y configuración de servicios

# 1. Actualizar repositorios y habilitar el repo testing de edge
#    (los cores libretro de SNES y N64 solo existen ahí para aarch64:
#     libretro-snes9x y libretro-parallel-n64; las ramas estables no los llevan)
if grep -q '/edge/' /etc/apk/repositories && ! grep -q '/edge/testing' /etc/apk/repositories; then
    EDGE_BASE="$(grep -E '/edge/(main|community)' /etc/apk/repositories | head -n 1 | sed 's|/[^/]*$||')"
    [ -n "$EDGE_BASE" ] || EDGE_BASE="https://dl-cdn.alpinelinux.org/alpine/edge"
    echo "$EDGE_BASE/testing" >> /etc/apk/repositories
fi
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

# 3. Cores de emulación: SNES (snes9x) y N64 (parallel-n64)
#    Grupo virtual aparte: si fallan, no impide instalar el resto del kiosk.
#    Los .so caen en /usr/lib/libretro, que es donde RetroArch los busca (config de Alpine).
apk add --virtual retro-cores libretro-parallel-n64 libretro-snes9x || \
    echo "AVISO: no se pudieron instalar los cores de SNES/N64 (requiere edge con el repo testing)."

# 4. Habilitar demonios de hardware e input en OpenRC (arranque automático)
rc-update add udev sysinit
rc-update add udev-trigger sysinit
rc-update add seatd default

# 5. Iniciar los servicios en la sesión actual
rc-service udev start
rc-service udev-trigger start
rc-service seatd start

# 6. Añadir el usuario estándar a los grupos de hardware
# NOTA: Reemplaza "tu_usuario" por tu nombre de usuario real en Alpine
TARGET_USER="admin"
addgroup $TARGET_USER video
addgroup $TARGET_USER input
addgroup $TARGET_USER audio
addgroup $TARGET_USER seat

# 7. Auto-login en tty1 con agetty (https://wiki.alpinelinux.org/wiki/TTY_Autologin)
# Se borra la línea tty1 existente y se añade la nueva para no depender del formato exacto.
# Si agetty no se instaló, no se toca /etc/inittab (se conserva el getty por defecto de busybox).
if command -v agetty >/dev/null 2>&1; then
    sed -i '/^tty1::/d' /etc/inittab
    echo "tty1::respawn:/sbin/agetty --autologin $TARGET_USER tty1 linux" >> /etc/inittab
fi

# 8. Auto-arrancar el kiosk desde .profile, solo cuando la sesión es tty1.
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

# 9. Audio de RetroArch: usar la API PulseAudio (pipewire-pulse) en vez de ALSA,
#    para no disputarse el dispositivo PCM con wireplumber, y forzar sin mute y volumen al máximo.
#    Si el cfg no existe se crea con estas claves; RetroArch completa el resto al arrancar.
RA_CFG="/home/$TARGET_USER/.config/retroarch/retroarch.cfg"
mkdir -p "$(dirname "$RA_CFG")"
set_ra() {
    if grep -q "^[# ]*$1 =" "$RA_CFG" 2>/dev/null; then
        sed -i "s|^[# ]*$1 =.*|$1 = \"$2\"|" "$RA_CFG"
    else
        echo "$1 = \"$2\"" >> "$RA_CFG"
    fi
}
set_ra audio_driver "pulse"
set_ra audio_volume "0.000000"
set_ra audio_mute_enable "false"
chown -R $TARGET_USER:$TARGET_USER "/home/$TARGET_USER/.config"

echo "Instalación completada. REINICIA el equipo para aplicar el autologin (agetty) y los cambios de grupos."
