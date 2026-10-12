# Troubleshooting: síntoma → causa probable → remedio

Aplica un remedio a la vez y registra el resultado. Si dos remedios distintos fallan igual, escribe handoff BLOQUEADO.

## Construcción

| Síntoma | Causa probable | Remedio |
|---|---|---|
| `git clone` del tag falla ("not found") | El tag no existe o el repo se movió | Repite `git ls-remote --tags`; usa el respaldo (`v2.54.2` o `v2.50.0`) y anótalo |
| CMake se queja de versión mínima | CMake nuevo con código viejo | Añade `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`, o instala un CMake más viejo en la imagen |
| `rosdep` intenta instalar `librealsense2` por apt | Pisaría tu build congelada | Usa `rosdep install --skip-keys=librealsense2` |
| Faltan paquetes como `libusb-1.0-0-dev` o `libudev-dev` | Dependencia no declarada | Instálalas en el Dockerfile y reconstruye |
| Out of memory al compilar | Demasiados hilos | Cambia `make -j$(nproc)` por `make -j2` |
| El wrapper 4.51.1 no compila en Humble | Incompatibilidad de distro | Revisa su README; si lo pide, cambia la base a Foxy (Ubuntu 20.04) como en el repo de comunidad |

## Detección de cámara

| Síntoma | Causa probable | Remedio |
|---|---|---|
| `lsusb` no muestra el dispositivo Intel | Hardware: cable, puerto, alimentación | Otro cable USB 3, otro puerto directo (sin hub), otra máquina. No sigas con software hasta resolver esto |
| `lsusb` lo ve pero `rs-enumerate-devices` no | Permisos o udev dentro del contenedor | Verifica las reglas `--device-cgroup-rule` y el montaje de `/dev`; copia las reglas udev de librealsense al host (compuerta humana: sudo) |
| Detecta pero se desconecta o dice USB 2.1 | Cable o puerto USB 2 | Cable USB 3 corto y de calidad, puerto azul/USB 3 directo |
| Falla con RSUSB | Limitación del backend con este modelo | Plan B: backend nativo con parches de kernel en el host. Solo con humano y sudo; registra la decisión y que ata el sistema a ese kernel |
| Error de firmware ("requires firmware") | Firmware distinto al esperado | **No actualizar firmware.** Anota la versión y consulta al usuario |

## Streaming y ROS

| Síntoma | Causa probable | Remedio |
|---|---|---|
| Frames nulos o timeouts | Ancho de banda USB o perfil no soportado | Usa el perfil por defecto del sensor; baja resolución o FPS; un solo dispositivo en el bus |
| El wrapper corre pero no hay tópicos de depth | Nombres o parámetros distintos | `ros2 topic list`; revisa los parámetros de `rs_launch.py` de esa versión |
| El host no ve los tópicos | DDS/red | `--network host`, mismo `ROS_DOMAIN_ID`, mismo `RMW_IMPLEMENTATION`; si usas rmw distinto prueba `rmw_cyclonedds_cpp` en ambos |
| Host ve la lista pero no recibe datos | QoS distinto | Suscríbete con `qos_profile_sensor_data` (best effort) |
| Imágenes de depth se ven negras | Es `16UC1` en milímetros | Normaliza y aplica un colormap antes de mostrar (ver `livekit-bridge.md`) |

## Cuándo parar

Si el problema señala al firmware, al protocolo propietario, o exige modificar el firmware: detente y avisa al usuario. Esta skill no cubre eso.
