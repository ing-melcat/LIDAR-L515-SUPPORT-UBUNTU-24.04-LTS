#!/usr/bin/env bash
# Reconocimiento del host. Solo lee, no modifica nada.
echo "# Reporte del host — $(date -Iseconds)"
echo; echo "## Sistema"
lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release
echo "Kernel: $(uname -r)"; echo "Arquitectura: $(uname -m)"
echo; echo "## USB (dispositivos Intel, vendor 8086)"
lsusb 2>/dev/null | grep -i "8086" || echo "(ningún dispositivo Intel visible: ¿cámara conectada?)"
echo; echo "## USB 3 (velocidad 5000M o mayor)"
lsusb -t 2>/dev/null | grep -E "5000M|10000M" || echo "(ningún dispositivo en USB 3 detectado)"
echo; echo "## Docker"
if command -v docker >/dev/null; then
  docker --version
  docker info >/dev/null 2>&1 && echo "Uso sin sudo: SÍ" || echo "Uso sin sudo: NO (¿falta el grupo docker?)"
else echo "Docker: NO instalado"; fi
echo; echo "## ROS2 instalado"
ls /opt/ros 2>/dev/null || echo "(ninguna distro en /opt/ros)"
echo; echo "## Usuario y grupos"
id
echo; echo "## Pantalla (para realsense-viewer)"
echo "DISPLAY=${DISPLAY:-<vacío, sesión sin gráficos>}"
echo; echo "## Espacio libre"
df -h . | tail -1
echo; echo "## Memoria"
free -h | sed -n 1,2p
