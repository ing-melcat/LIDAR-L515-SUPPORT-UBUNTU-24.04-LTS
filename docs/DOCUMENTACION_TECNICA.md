# 📖 Documentación Integral del Sistema: Intel RealSense L515 en ROS 2 Moderno

> **Estado del Proyecto:** Operativo, Containerizado y Validado  
> **Hardware Principal:** Sensor LiDAR de Estado Sólido Intel RealSense L515  
> **Sistemas Operativos / Middleware:** Ubuntu 24.04 (Host / ROS 2 Jazzy) ↔ Ubuntu 22.04 (Docker / ROS 2 Humble)  
> **Protocolo de Comunicación:** CycloneDDS (`ROS_DOMAIN_ID=42`)  
> **Servicios Externos:** LiveKit Cloud (Teleoperación WebRTC)  

---

## 1. El Problema y Justificación de la Arquitectura

### El Dilema del Sensor Descontinuado
El sensor **Intel RealSense L515** es un LiDAR de estado sólido de alta precisión que combina una cámara de profundidad por tiempo de vuelo láser con un sensor RGB. Sin embargo:
- Intel descontinuó oficialmente la línea L515 en 2021/2022.
- El soporte fue removido del SDK oficial `librealsense` a partir de la versión **v2.55.1** y del wrapper oficial `realsense-ros` a partir de la versión **v4.54.1**.
- Las distribuciones modernas de Linux como **Ubuntu 24.04 LTS (Noble Numbat)** con **ROS 2 Jazzy Jalisco** utilizan versiones de Kernel (Linux 6.8+), compiladores GCC 13/14 y dependencias de CMake incompatibles con los drivers heredados del L515. Compilarlos de forma nativa en el sistema anfitrión rompe el sistema operativo o genera fallos de enlace.

### La Estrategia: Aislamiento y Congelamiento (Docker + RSUSB)
En lugar de forzar parches inestables en el sistema anfitrión, la arquitectura encapsula el controlador dentro de un contenedor **Docker** inmutable:
- **Base del Contenedor:** Ubuntu 22.04 LTS + ROS 2 Humble Hawksbill.
- **Backend RSUSB:** Se compila `librealsense v2.54.1` con la bandera `-DFORCE_RSUSB_BACKEND=ON`. Esto permite el acceso al hardware mediante espacio de usuario (`libusb`), eliminando por completo la necesidad de parches en los módulos del kernel de Linux. El contenedor funciona en cualquier host sin importar la versión de su kernel.
- **Wrapper ROS 2:** `realsense-ros v4.51.1`, configurado para publicar tópicos estándar de ROS 2.

---

## 2. Capa de Red y Comunicación Inter-Procesos (CycloneDDS)

Para que un contenedor en **ROS 2 Humble** y aplicaciones en el host en **ROS 2 Jazzy** se comuniquen de forma transparente sin cuellos de botella:
1. **Red del Contenedor:** Se ejecuta con `--network host`, compartiendo la interfaz de loopback y red de la máquina.
2. **Middleware RMW:** Se utiliza `rmw_cyclonedds_cpp` en ambos extremos. El RMW por defecto (FastDDS) suele fragmentar o perder paquetes de gran tamaño (como `sensor_msgs/msg/PointCloud2` de 15 a 30 MB/s). CycloneDDS garantiza entrega determinista sin saturación.
3. **Identificador de Dominio:** Ambos extremos operan bajo la variable de entorno:
   ```bash
   export ROS_DOMAIN_ID=42
   export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
   ```

---

## 3. Tópicos Clave Publicados por la Cámara

| Tópico | Tipo de Mensaje | Frecuencia Típica | Propósito |
| :--- | :--- | :--- | :--- |
| `/camera/color/image_raw` | `sensor_msgs/msg/Image` | 30 Hz | Video RGB para teleoperación y SLAM visual |
| `/camera/aligned_depth_to_color/image_raw` | `sensor_msgs/msg/Image` | 30 Hz | Imagen de profundidad geométricamente alineada al sensor RGB |
| `/camera/color/camera_info` | `sensor_msgs/msg/CameraInfo` | 30 Hz | Intrínsecos y matriz de proyección de la lente |
| `/camera/depth/color/points` | `sensor_msgs/msg/PointCloud2` | 15 - 30 Hz | Nube de puntos 3D densa generada por el LiDAR |
| `/camera/imu` | `sensor_msgs/msg/Imu` | 200 - 400 Hz | Datos combinados de acelerómetro y giroscopio (opcional) |

---

## 4. Teleoperación en la Nube: LiveKit Bridge

Para que un operador remoto pueda conducir el robot o vigilar la cámara desde cualquier lugar a través de internet:
- **Ubicación:** `~/venvs/l515-livekit` + `scripts/l515_livekit_bridge.py`.
- **Funcionamiento:** 
  1. El script inicializa un nodo de ROS 2 Jazzy que se suscribe al tópico de color `/camera/color/image_raw`.
  2. Convierte los mensajes `sensor_msgs/Image` a frames de video compatibles con WebRTC.
  3. Se conecta de forma segura a LiveKit Cloud utilizando WebSockets (`wss://rassor-0dr12g8u.livekit.cloud`) con credenciales por variables de entorno.
  4. Publica una pista de video en la sala (`room-1`) con latencia inferior a 150 ms.

---

## 5. Mapeo 3D y Odometría (SLAM)

Durante el desarrollo se probaron y resolvieron los retos críticos de navegación 3D:

### A. RTAB-Map SLAM (Mapeo Denso por CPU)
- **Aspect Ratio Mismatch:** RTAB-Map exige que la imagen RGB y la de profundidad compartan idéntica relación de aspecto para proyectar los rayos 3D. Se resolvió fijando ambos módulos a `640x480x30`.
- **Filtros contra Ruido LiDAR:** El LiDAR genera micro-vibraciones espaciales en reposo que el algoritmo visual confunde con desplazamiento ("deriva fantasma"). Se resolvieron activando en hardware:
  - `spatial_filter.enable:=true`: Suavizado 2D preservando bordes.
  - `temporal_filter.enable:=true`: Promedio temporal de fotogramas que congela los píxeles cuando el sensor está quieto.
- **Límite de la Odometría Visual Pura:** Los movimientos bruscos producen desenfoque de movimiento (*motion blur*), provocando que la odometría pierda el seguimiento (`quality=0`).

### B. OctoMap (Mapeo de Voxeles Ligero para Raspberry Pi 4)
Para hardware de cómputo limitado (como una Raspberry Pi 4):
- Ignora el canal RGB por completo para no saturar memoria.
- Toma la nube de puntos `/camera/depth/color/points` y genera un árbol octal (Octree) de cubos 3D ocupados/libres.
- Consume una fracción mínima de CPU y RAM, permitiendo navegación y evasión de obstáculos en 3D.

---

## 6. Hoja de Ruta: Integración con Nvidia Isaac ROS

Para la arquitectura de producción del robot, el flujo recomendado es:
1. **Cálculo en GPU:** La cámara no debe calcular el mapa de puntos en CPU. En su lugar, envía la profundidad cruda a `isaac_ros_depth_image_proc`, que genera la nube 3D en milisegundos usando núcleos CUDA.
2. **cuVSLAM Robusto:** `isaac_ros_visual_slam` reemplaza la odometría por CPU de RTAB-Map, permitiendo movimientos rápidos y giros bruscos sin perder el mapa.
3. **Fusión Sensorial:** Se complementa con la odometría de los motores de las ruedas, haciendo el sistema invulnerable a pérdidas visuales.

---

## 7. Guía de Ejecución Rápida

### Lanzamiento de la Cámara (Terminal 1)
```bash
sudo docker rm -f realsense_cyclonedds 2>/dev/null
sudo docker run --rm --name realsense_cyclonedds \
  --network host \
  -e ROS_DOMAIN_ID=42 \
  -e RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
  -v /dev:/dev \
  --device-cgroup-rule='c 189:* rmw' \
  --device-cgroup-rule='c 81:* rmw' \
  l515-ros:20261007 bash -c "source /opt/ros/humble/setup.bash && source /opt/ws/install/setup.bash && ros2 launch realsense2_camera rs_launch.py align_depth.enable:=true pointcloud.enable:=true depth_module.profile:=640x480x30 rgb_camera.profile:=640x480x30 spatial_filter.enable:=true temporal_filter.enable:=true"
```

### Lanzamiento de Mapeo RTAB-Map (Terminal 2)
```bash
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=42
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

ros2 launch rtabmap_launch rtabmap.launch.py \
    rtabmap_args:="--delete_db_on_start" \
    rgb_topic:=/camera/color/image_raw \
    depth_topic:=/camera/aligned_depth_to_color/image_raw \
    camera_info_topic:=/camera/color/camera_info \
    frame_id:=camera_link \
    approx_sync:=true \
    qos:=2 \
    rviz:=true
```

### Lanzamiento del Puente de LiveKit (Terminal 3 - Opcional)
```bash
source ~/venvs/l515-livekit/bin/activate
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=42
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export LIVEKIT_URL="wss://rassor-0dr12g8u.livekit.cloud"
export LIVEKIT_API_KEY="API2PsLkHiairam"
export LIVEKIT_API_SECRET="aIfD6YBQe8eA8BQDf0xuv5Oy0ypZjr38ZSwOqdeZWUUB"
export LIVEKIT_ROOM="room-1"

python3 /home/central-remote/Downloads/realsense-l515-support/scripts/l515_livekit_bridge.py
```
