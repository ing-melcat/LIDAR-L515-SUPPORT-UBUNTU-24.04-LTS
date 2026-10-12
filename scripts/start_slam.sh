#!/usr/bin/env bash
# ==============================================================================
# Script de Lanzamiento: RTAB-Map SLAM 3D en Host (ROS 2 Jazzy)
# ==============================================================================
set -euo pipefail

echo "==> Cargando entorno de ROS 2 Jazzy y CycloneDDS..."
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=42
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

echo "==> Iniciando RTAB-Map SLAM y RViz2..."
ros2 launch rtabmap_launch rtabmap.launch.py \
    rtabmap_args:="--delete_db_on_start" \
    rgb_topic:=/camera/color/image_raw \
    depth_topic:=/camera/aligned_depth_to_color/image_raw \
    camera_info_topic:=/camera/color/camera_info \
    frame_id:=camera_link \
    approx_sync:=true \
    qos:=2 \
    rviz:=true
