#!/bin/sh
# setup.sh - Instalación de dependencias y configuración de servicios

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
    alsa-utils
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

echo "Instalación completada. Por favor, CIERRA SESIÓN y vuelve a entrar para aplicar los grupos."
