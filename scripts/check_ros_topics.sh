#!/usr/bin/env bash
# Lista tópicos y mide frecuencia de imágenes. Ejecutar con el wrapper corriendo y ROS cargado.
set -u
source /opt/ros/*/setup.bash 2>/dev/null
[ -f /opt/ws/install/setup.bash ] && source /opt/ws/install/setup.bash
echo "## Tópicos que contienen 'camera'"
ros2 topic list | grep -i camera || { echo "FAIL: no hay tópicos de cámara"; exit 2; }
for pat in "depth/image" "color/image"; do
  t=$(ros2 topic list | grep -E "$pat" | grep -v -E "compressed|theora|zstd" | head -1)
  if [ -z "$t" ]; then echo "FAIL: sin tópico para '$pat'"; continue; fi
  echo; echo "## Frecuencia de $t (8 s)"
  timeout 8 ros2 topic hz "$t" 2>&1 | tail -4
done
