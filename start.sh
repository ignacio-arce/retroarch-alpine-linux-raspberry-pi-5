#!/bin/sh
# lanzar_retroarch.sh - Wrapper para inicializar Cage y RetroArch
# 1. Configurar y crear el directorio de ejecución de Wayland en RAM (/tmp)
export XDG_RUNTIME_DIR=/tmp/$(id -u)-runtime-dir
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
fi

# 2. Forzar variables de entorno para maximizar la compatibilidad Wayland/GLES
export XDG_SESSION_TYPE=wayland
export LIBGL_ALWAYS_SOFTWARE=0
export QT_QPA_PLATFORM=wayland

# 3. Lanzar Cage ejecutando RetroArch
# El flag -d de Cage oculta cualquier decoración de puntero inactiva.
pipewire & 
wireplumber & 
pipewire-pulse &
exec cage -d -- retroarch
