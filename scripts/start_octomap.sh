#!/usr/bin/env bash
# ==============================================================================
# Script de Lanzamiento: Mapeo Ligero de Voxeles 3D (OctoMap) para RPi 4 / Host
# ==============================================================================
set -euo pipefail

echo "==> Configurando entorno de ROS 2 Jazzy y CycloneDDS..."
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=42
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

echo "==> Lanzando servidor de OctoMap (Resolución: 0.05m)..."
ros2 run octomap_server octomap_server_node --ros-args \
  -p frame_id:=camera_link \
  -p resolution:=0.05 \
  -r cloud_in:=/camera/depth/color/points &
OCTO_PID=$!

trap "kill $OCTO_PID 2>/dev/null || true" EXIT

echo "==> Lanzando RViz2 para visualización..."
echo "==> NOTA EN RVIZ: Fixed Frame = 'camera_link', agregar tópico '/octomap_binary' o '/octomap_full'."
rviz2
