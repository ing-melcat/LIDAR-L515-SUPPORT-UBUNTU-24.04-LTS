# Fases: comandos paso a paso

Convención: `$WS` = carpeta `workspace/` del proyecto. Todos los comandos asumen que ya estás dentro del proyecto. Pega las salidas reales en los handoffs.

## Fase 0: Preparación

```bash
mkdir -p workspace/handoffs workspace/inbox workspace/logs
cp <ruta-de-la-skill>/assets/STATE.template.md workspace/STATE.md
cp <ruta-de-la-skill>/assets/Dockerfile.l515 .
cp <ruta-de-la-skill>/assets/run_container.sh .
chmod +x run_container.sh
echo "workspace/inbox/" >> .gitignore; echo ".env" >> .gitignore
```
Después haz el intake (ver SKILL.md) y anota las respuestas en STATE.md.

## Fase 1: Descubrimiento (R0 y R1 en paralelo)

R0:
```bash
bash <ruta-de-la-skill>/scripts/host_recon.sh | tee workspace/handoffs/01_host.md
```
R1: confirma tags y URLs.
```bash
git ls-remote --tags https://github.com/IntelRealSense/librealsense.git | grep -E 'v2\.(50\.0|54\.1|54\.2)$'
git ls-remote --tags https://github.com/IntelRealSense/realsense-ros.git | grep -E '4\.51\.1'
```
Si el repo redirige, usa la URL nueva que devuelva git y anótala. Criterio: los 4 tags aparecen o queda anotado cuál falta y qué respaldo se usa.

## Fase 2: Construcción (R2)

Compuertas humanas posibles: si Docker no está instalado o el usuario no está en el grupo `docker`, pide al humano:
```bash
sudo apt-get update && sudo apt-get install -y docker.io
sudo usermod -aG docker "$USER"   # luego cerrar sesión y volver a entrar
```
Construcción (puede tardar 20 a 60 minutos por la compilación de librealsense):
```bash
docker build \
  --build-arg LRS_TAG=v2.54.1 \
  --build-arg RS_ROS_TAG=4.51.1 \
  -t l515-ros:$(date +%Y%m%d) -f Dockerfile.l515 . 2>&1 | tee workspace/logs/build.log
```
Verificación (sin cámara):
```bash
docker run --rm l515-ros:$(date +%Y%m%d) bash -lc '
  rs-enumerate-devices --version;
  python3 -c "import pyrealsense2 as rs; print(rs.__version__)";
  source /opt/ros/humble/setup.bash && source /opt/ws/install/setup.bash;
  ros2 pkg list | grep realsense'
```
Criterio: las tres salidas existen. Si falla, ver `troubleshooting.md` sección "Construcción".

## Fase 3: Validación con cámara (R3 + humano)

1. Humano: conectar la cámara a un puerto USB 3 con cable de calidad. Confirmar en el host: `lsusb | grep -i 8086` (debe aparecer un dispositivo Intel).
2. Arrancar el contenedor indicando dónde está la skill (para montar sus scripts): `SKILL_DIR=<ruta-de-la-skill> ./run_container.sh l515-ros:$(date +%Y%m%d)`
3. Dentro del contenedor:
```bash
rs-enumerate-devices -s
python3 /opt/skill/scripts/validate_camera.py
```
   (`run_container.sh` monta la carpeta `scripts/` de la skill en `/opt/skill/scripts`.)
4. Lanzar el wrapper (en una segunda terminal dentro del contenedor, `docker exec -it l515 bash`):
```bash
source /opt/ros/humble/setup.bash && source /opt/ws/install/setup.bash
ros2 launch realsense2_camera rs_launch.py enable_depth:=true enable_color:=true
```
5. En otra terminal dentro del contenedor: `bash /opt/skill/scripts/check_ros_topics.sh`

Criterio: `validate_camera.py` imprime `PASS`; `check_ros_topics.sh` muestra frecuencia > 0 para depth y color. Los nombres de tópicos del wrapper pueden variar por versión: usa `ros2 topic list` y registra los reales en STATE.md.

## Fase 4: Integración

R4: en el host (24.04) con Jazzy instalado:
```bash
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=<el mismo que el contenedor>
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp   # si se usó en el contenedor
ros2 topic list
ros2 topic hz /camera/camera/depth/image_rect_raw
```
Criterio: el host ve los mismos tópicos y mide frecuencia > 0.

R5 y R6 en paralelo: ver `livekit-bridge.md` e `isaac.md`.

## Fase 5: Congelación (R7)

```bash
bash <ruta-de-la-skill>/scripts/freeze_image.sh l515-ros:<tag> ./freeze
```
Genera `freeze/<imagen>.tar.gz` y `freeze/SHA256SUMS`. Escribe `versions.lock` y `GUIA_REPRODUCCION.md`. Criterio: restaurar con `docker load < freeze/<imagen>.tar.gz` y repetir la Fase 3 en seco (sin recompilar).

## Fase 6: Revisión (R8)

Sigue el rol R8 de `roles.md`. Criterio: cero bloqueantes abiertos.
