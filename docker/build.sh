#!/usr/bin/env bash
# ==============================================================================
# Script de Construcción: Imagen Docker para Intel RealSense L515 en ROS 2 Humble
# ==============================================================================
set -euo pipefail

IMAGE_NAME="l515-ros:20261007"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Construyendo imagen Docker: ${IMAGE_NAME}..."
echo "==> Directorio de contexto: ${SCRIPT_DIR}"

docker build \
  -t "${IMAGE_NAME}" \
  -f "${SCRIPT_DIR}/Dockerfile" \
  "${SCRIPT_DIR}"

echo "==> ¡Construcción completada exitosamente!"
echo "==> Imagen lista: ${IMAGE_NAME}"
