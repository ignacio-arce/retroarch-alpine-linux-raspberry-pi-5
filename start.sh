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

# 3. Lanzar la pila de audio EN ORDEN: pipewire -> su socket -> wireplumber -> pipewire-pulse.
# Si wireplumber arranca antes que pipewire, no encuentra el socket, sale sin crear
# sinks y todo queda en silencio (el fallo clásico de "no se escucha nada").
pipewire &
TRIES=0
while [ ! -S "$XDG_RUNTIME_DIR/pipewire-0" ] && [ "$TRIES" -lt 50 ]; do
    sleep 0.1 2>/dev/null || :
    TRIES=$((TRIES + 1))
done
wireplumber &
pipewire-pulse &

# 4. Lanzar Cage ejecutando RetroArch
# El flag -d de Cage oculta cualquier decoración de puntero inactiva.
exec cage -d -- retroarch
