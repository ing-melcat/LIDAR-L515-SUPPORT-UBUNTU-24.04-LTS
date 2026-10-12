# Guía de Reproducción (RealSense L515 Congelado)

## ADVERTENCIA: Qué NO actualizar nunca
El entorno del contenedor está **congelado en el tiempo** para preservar la compatibilidad con el L515.
- **NO actualices el firmware del L515** (ya no está soportado).
- **NO cambies la imagen base del contenedor** a nada superior a Ubuntu 22.04 (Humble), ni cambies el RMW a algo que no sea CycloneDDS.

## Cómo restaurar en una Raspberry Pi 4 (o máquina limpia)

1. **Instalar dependencias en el nuevo host:**
   ```bash
   sudo apt-get update
   sudo apt-get install -y docker.io ros-jazzy-rmw-cyclonedds-cpp
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **Cargar la imagen de Docker congelada:**
   Transfiere el archivo `l515-ros_20261007.tar.gz` a la nueva máquina y ejecuta:
   ```bash
   docker load < l515-ros_20261007.tar.gz
   ```

3. **Conectar la cámara y levantar el contenedor:**
   ```bash
   docker run -it --rm --name l515_camera \
     --network host \
     -e ROS_DOMAIN_ID=42 \
     -e RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
     -v /dev:/dev \
     --device-cgroup-rule='c 189:* rmw' \
     --device-cgroup-rule='c 81:* rmw' \
     l515-ros:20261007 \
     bash -c "source /opt/ros/humble/setup.bash && source /opt/ws/install/setup.bash && ros2 launch realsense2_camera rs_launch.py"
   ```

4. **Levantar puente LiveKit (Opcional):**
   ```bash
   python3 -m venv ~/venvs/l515-livekit --system-site-packages
   source ~/venvs/l515-livekit/bin/activate
   pip install livekit livekit-api numpy opencv-python-headless
   # Exportar variables y correr script de python
   ```
