# 📡 Intel RealSense L515 Support (ROS 2 Humble / Jazzy + LiveKit + SLAM)

> **Soporte Completo y Contenedor Inmutable para el sensor LiDAR de Estado Sólido Intel RealSense L515.**  
> Permite operar la cámara descontinuada en **Ubuntu 24.04 (ROS 2 Jazzy)** mediante un contenedor aislado en **ROS 2 Humble**, transporte determinista con **CycloneDDS**, puente de teleoperación WebRTC con **LiveKit Cloud** y mapeo 3D con **RTAB-Map** y **OctoMap**.

---

## 🏗️ Arquitectura del Sistema

```
                  ┌────────────────────────────────────────┐
                  │ Intel RealSense L515 (LiDAR + RGB)     │
                  └──────────────────┬─────────────────────┘
                                     │ USB 3.0 Passthrough
                                     ▼
        ┌────────────────────────────────────────────────────────┐
        │ Contenedor Docker: l515-ros:20261007                   │
        │ - Ubuntu 22.04 LTS + ROS 2 Humble                      │
        │ - librealsense v2.54.1 (Backend RSUSB en User-Space)   │
        │ - realsense-ros v4.51.1                                │
        └────────────────────────────┬───────────────────────────┘
                                     │ CycloneDDS (ROS_DOMAIN_ID=42)
                                     ▼
       ┌──────────────────────────────────────────────────────────┐
       │ Sistema Anfitrión / Robot (Ubuntu 24.04 / ROS 2 Jazzy)   │
       ├────────────────────────┬─────────────────────────────────┤
       │ Teleoperación          │ Mapeo 3D / Percepción           │
       │ - l515_livekit_bridge  │ - RTAB-Map SLAM (RGB-D)         │
       │   (WebRTC a LiveKit)   │ - OctoMap Server (Voxeles RPi4) │
       │                        │ - Nvidia Isaac ROS (cuVSLAM)    │
       └────────────────────────┴─────────────────────────────────┘
```

---

## 📁 Estructura del Repositorio

```text
realsense-l515-support/
├── docker/
│   ├── Dockerfile                  # Receta reproducible de librealsense 2.54.1 + realsense-ros
│   └── build.sh                    # Script de un solo comando para compilar la imagen
├── scripts/
│   ├── start_camera.sh             # Lanza el contenedor de la cámara con parámetros optimizados
│   ├── start_slam.sh               # Lanza RTAB-Map SLAM y visualización en RViz2
│   ├── start_octomap.sh            # Lanza OctoMap para mapeo ligero de voxeles 3D
│   ├── start_livekit.sh            # Inicia el puente de teleoperación WebRTC a LiveKit Cloud
│   ├── l515_livekit_bridge.py      # Nodo ROS 2 -> WebRTC LiveKit
│   ├── validate_camera.py          # Script de prueba básica de captura USB
│   └── check_ros_topics.sh         # Diagnóstico de frecuencias de tópicos ROS 2
├── docs/
│   ├── INFORME_TECNICO_L515_FORMAL.docx  # Informe formal ejecutivo en Word
│   ├── DOCUMENTACION_TECNICA.md          # Manual técnico exhaustivo
│   └── GUIA_REPRODUCCION_RPI4.md         # Guía de migración a Raspberry Pi 4
├── references/                     # Referencias técnicas y hojas de datos
├── .env.example                    # Plantilla de variables de entorno para LiveKit
├── .gitignore                      # Exclusión de credenciales y binarios pesados
└── README.md                       # Esta guía
```

---

## 🚀 Guía de Inicio Rápido (Quickstart)

### Requisitos Previos en el Host
- Ubuntu 22.04 o Ubuntu 24.04 con **Docker** instalado.
- ROS 2 (Humble o Jazzy) con el paquete CycloneDDS:
  ```bash
  sudo apt-get update && sudo apt-get install -y ros-$ROS_DISTRO-rmw-cyclonedds-cpp
  sudo usermod -aG docker $USER && newgrp docker
  ```

---

### Paso 1: Construir la Imagen de Docker (Solo la primera vez)
Si aún no tienes la imagen compilada:
```bash
./docker/build.sh
```
*(Esto compila `librealsense v2.54.1` con backend RSUSB y `realsense-ros 4.51.1` de forma limpia).*

---

### Paso 2: Encender la Cámara
Conecta la Intel RealSense L515 a un puerto **USB 3.0** (azul) y ejecuta:
```bash
./scripts/start_camera.sh
```
> **Nota de Estabilidad:** Este script incluye automáticamente la corrección de relación de aspecto (640x480) y activa los filtros espaciales y temporales de hardware para eliminar la vibración milimétrica del láser.

---

### Paso 3: Mapeo 3D (Elige una opción)

#### Opción A: RTAB-Map SLAM (Mapeo denso con visualización)
En una segunda terminal:
```bash
./scripts/start_slam.sh
```
*Se abrirá RViz2 con el mapa 3D y la trayectoria de la cámara.*

#### Opción B: OctoMap (Mapeo ligero en voxeles para Raspberry Pi 4)
En una segunda terminal:
```bash
./scripts/start_octomap.sh
```
*Construye un mundo volumétrico en cubos 3D de 5 cm consumiendo mínima CPU.*

---

### Paso 4: Teleoperación en la Nube con LiveKit (Opcional)
Para transmitir video en vivo a un navegador web desde cualquier lugar:

1. Configura tus credenciales:
   ```bash
   cp .env.example .env
   # Edita .env con tu LIVEKIT_URL, API_KEY y API_SECRET
   ```
2. Instala dependencias e inicia el puente:
   ```bash
   python3 -m venv ~/venvs/l515-livekit --system-site-packages
   source ~/venvs/l515-livekit/bin/activate
   pip install livekit livekit-api numpy opencv-python-headless

   ./scripts/start_livekit.sh
   ```

---

## 📊 Tópicos ROS 2 Publicados

| Tópico | Tipo | Frecuencia | Descripción |
| :--- | :--- | :--- | :--- |
| `/camera/color/image_raw` | `sensor_msgs/Image` | 30 Hz | Video RGB para teleoperación |
| `/camera/aligned_depth_to_color/image_raw` | `sensor_msgs/Image` | 30 Hz | Profundidad alineada con RGB |
| `/camera/color/camera_info` | `sensor_msgs/CameraInfo` | 30 Hz | Calibración de la lente |
| `/camera/depth/color/points` | `sensor_msgs/PointCloud2` | 15 - 30 Hz | Nube de puntos 3D LiDAR |

---

## 🔒 Seguridad y Buenas Prácticas
- **Credenciales:** Nunca subas el archivo `.env` al repositorio. Se encuentra protegido por `.gitignore`.
- **Imágenes Pesadas:** Los respaldos `.tar.gz` de Docker superan el límite de 100 MB de GitHub y están excluidos del control de versiones. Usa `./docker/build.sh` para reproducir la imagen de forma idéntica en cualquier máquina.

---

## 📄 Documentación Adicional
Para más detalles sobre la arquitectura de hardware, la fenomenología del láser y la hoja de ruta hacia **Nvidia Isaac ROS**, consulta:
* [Informe Técnico Ejecutivo (Word)](docs/INFORME_TECNICO_L515_FORMAL.docx)
* [Manual Técnico Detallado](docs/DOCUMENTACION_TECNICA.md)
* [Guía de Migración a Raspberry Pi 4](docs/GUIA_REPRODUCCION_RPI4.md)
