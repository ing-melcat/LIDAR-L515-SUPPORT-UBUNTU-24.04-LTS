#!/usr/bin/env bash
# ==============================================================================
# Script de Lanzamiento: Puente WebRTC a LiveKit Cloud para Teleoperación
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Cargar variables de entorno desde .env si existe
if [ -f "${ROOT_DIR}/.env" ]; then
  echo "==> Cargando credenciales desde .env..."
  set -a
  source "${ROOT_DIR}/.env"
  set +a
else
  echo "==> AVISO: No se encontró archivo .env en la raíz del proyecto."
  echo "==> Asegúrate de haber definido: LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET, LIVEKIT_ROOM."
fi

# Validar variables requeridas
: "${LIVEKIT_URL:?Error: Variable LIVEKIT_URL no definida. Copia .env.example a .env}"
: "${LIVEKIT_API_KEY:?Error: Variable LIVEKIT_API_KEY no definida. Copia .env.example a .env}"
: "${LIVEKIT_API_SECRET:?Error: Variable LIVEKIT_API_SECRET no definida. Copia .env.example a .env}"
LIVEKIT_ROOM="${LIVEKIT_ROOM:-room-1}"

echo "==> Cargando ROS 2 Jazzy y CycloneDDS..."
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=42
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# Activar entorno virtual si existe
VENV_PATH="${HOME}/venvs/l515-livekit"
if [ -d "${VENV_PATH}" ]; then
  echo "==> Activando entorno virtual: ${VENV_PATH}..."
  source "${VENV_PATH}/bin/activate"
fi

echo "==> Iniciando puente LiveKit hacia sala: ${LIVEKIT_ROOM}..."
python3 "${SCRIPT_DIR}/l515_livekit_bridge.py"
