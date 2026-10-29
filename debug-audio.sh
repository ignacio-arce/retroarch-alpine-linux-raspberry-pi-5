#!/bin/sh
# debug-audio.sh - Diagnóstico de audio del kiosk. SOLO LEE, no cambia nada.
# Ejecutar como el usuario del kiosk (admin) y pegar la salida completa:
#     ./debug-audio.sh

echo "== 1. Usuario y grupos =="
echo "(debe aparecer 'audio' en los grupos; si no, falta reiniciar tras install.sh)"
id
echo

echo "== 2. Dispositivos de sonido del kernel =="
ls -l /dev/snd/ 2>/dev/null || echo "/dev/snd NO EXISTE (el kernel no cargó audio HDMI)"
echo

echo "== 3. Tarjetas ALSA =="
if command -v aplay >/dev/null 2>&1; then
    aplay -l 2>&1 || echo "(aplay no encontró tarjetas)"
else
    echo "aplay no está instalado (falta alsa-utils)"
fi
echo

echo "== 4. Controles/mute de la tarjeta 0 =="
if command -v amixer >/dev/null 2>&1; then
    amixer -c 0 2>&1 | head -40 || echo "(no se pudo leer la tarjeta 0)"
else
    echo "amixer no está instalado (falta alsa-utils)"
fi
echo

# El kiosk crea el socket de pipewire en /tmp/<uid>-runtime-dir (misma ruta si
# entras por SSH con el mismo usuario), así que se puede consultar desde fuera.
RT="/tmp/$(id -u)-runtime-dir"
echo "== 5. Pila de audio (PipeWire) =="
if [ -S "$RT/pipewire-0" ]; then
    export XDG_RUNTIME_DIR="$RT"
    for p in pipewire wireplumber pipewire-pulse; do
        if pidof "$p" >/dev/null 2>&1; then
            echo "  $p: CORRIENDO (pid $(pidof "$p" | tr ' ' ','))"
        else
            echo "  $p: NO CORRE  <-- causa probable de silencio"
        fi
    done
    echo
    echo "-- Sinks de PipeWire (si no sale ningún 'sink' --> no hay salida de audio) --"
    if command -v wpctl >/dev/null 2>&1; then
        wpctl status 2>&1 | sed -n '/Audio/,/Video/p'
        echo "-- Volumen del sink por defecto (si pone 'muted' --> silenciado) --"
        wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>&1
    else
        echo "wpctl no instalado (falta wireplumber)"
    fi
    echo
    echo "-- Cliente PulseAudio (donde RetroArch 'pulse' se conecta) --"
    if command -v pactl >/dev/null 2>&1; then
        pactl info 2>&1 | head -8
        pactl list sinks short 2>&1
    else
        echo "pactl no instalado (opcional: apk add pulseaudio-utils)"
    fi
else
    echo "Socket NO encontrado en $RT/pipewire-0"
    echo "  --> pipewire no ha arrancado en la sesión del kiosk (¿reiniciaste tras install.sh?)"
fi
echo

echo "== 6. Configuración de audio de RetroArch =="
CFG="$HOME/.config/retroarch/retroarch.cfg"
if [ -f "$CFG" ]; then
    grep -E '^[# ]*audio_(driver|volume|mute_enable|enable|out_rate) =' "$CFG" || \
        echo "(sin claves de audio en $CFG)"
else
    echo "No existe $CFG (RetroArch no ha arrancado nunca con este usuario)"
fi
echo

echo "== 7. Conclusión automática =="
if ! id | grep -q '\baudio\b'; then
    echo "FALTA el grupo 'audio': reinicia la Pi (install.sh no había aplicado grupos)."
elif [ ! -d /dev/snd ]; then
    echo "Sin /dev/snd: el kernel no cargó la tarjeta HDMI. Revisa el puerto HDMI con audio."
elif ! [ -S "$RT/pipewire-0" ]; then
    echo "PipeWire no corre en la sesión: vuelve a lanzar start.sh y mira sus errores."
elif ! command -v wpctl >/dev/null 2>&1 || [ -z "$(wpctl status 2>/dev/null | grep -i sink)" ]; then
    echo "Sin sinks: wireplumber no gestionó la tarjeta (grupos/permisos o carrera de arranque)."
else
    echo "La base parece OK: mira 'muted' y el volumen del sink, y el driver de RetroArch."
fi
