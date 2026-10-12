#!/usr/bin/env bash
# ==============================================================================
# Script de Lanzamiento: Nodo RealSense L515 (Docker)
# ==============================================================================
# - Red de host (--network host) con CycloneDDS y Domain ID 42.
# - Permisos automáticos para dispositivos USB sin requerir --privileged inseguro.
# - Resoluciones sincronizadas (640x480) para compatibilidad con algoritmos SLAM.
# - Filtros espaciales y temporales activados para estabilizar ruido de LiDAR.
# ==============================================================================
set -euo pipefail

IMAGE_NAME="l515-ros:20261007"
CONTAINER_NAME="realsense_cyclonedds"

echo "==> Verificando si existe un contenedor previo en ejecución..."
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "==> Deteniendo y eliminando contenedor previo: ${CONTAINER_NAME}..."
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

echo "==> Iniciando contenedor del sensor RealSense L515..."
docker run --rm --name "${CONTAINER_NAME}" \
  --network host \
  -e ROS_DOMAIN_ID=42 \
  -e RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
  -v /dev:/dev \
  --device-cgroup-rule='c 189:* rmw' \
  --device-cgroup-rule='c 81:* rmw' \
  "${IMAGE_NAME}" \
  bash -c "source /opt/ros/humble/setup.bash && source /opt/ws/install/setup.bash && \
  ros2 launch realsense2_camera rs_launch.py \
    align_depth.enable:=true \
    pointcloud.enable:=true \
    depth_module.profile:=640x480x30 \
    rgb_camera.profile:=640x480x30 \
    spatial_filter.enable:=true \
    temporal_filter.enable:=true"
