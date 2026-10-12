# Hechos, versiones y límites

Fecha de la investigación base: 2026-10-06. Todo lo marcado **VERIFICAR** debe comprobarse de nuevo (búsqueda web o comando) antes de usarlo, y el resultado va a `workspace/STATE.md`.

## Confirmado en fuentes consultadas

- Las notas de versión de librealsense (2.56.x a 2.58.x) siguen listando el L515 en su tabla de cámaras, pero solo como: firmware 1.5.8.1 o posterior, SDK **v2.50.0 validado**, y **v2.54.2 lo soporta pero no está validado**.
- Un ingeniero de soporte de RealSense (hilo de `realsense-ros`, issue #3122) indicó que el wrapper ROS2 **4.55.1 quitó el soporte del L515** por ser un modelo retirado, que librealsense **2.55.1** también lo quitó, y que el wrapper **4.54.1** ya lo había quitado. Sugirió el wrapper **4.51.1** como el más cercano a librealsense 2.53.1.
- Un repo de comunidad (`flyingmarkk/RealSense-L515-Docker`) usa Ubuntu 20.04 + ROS2 Foxy + librealsense **v2.54.1**, descrita ahí como la última versión que soporta el L515.
- Un port de SSL_SLAM2 a ROS2 Humble (`TiNredmc/ssl_slam2_ros2`, Ubuntu 22.04) usa el L515 como sensor de ejemplo.
- La guía de Isaac ROS lista como cámaras RealSense soportadas la D455 y la D435i (no el L515) y exige firmware 5.13.0.50, librealsense 2.55.1 y `realsense-ros` 4.51.1-isaac. Cualquier desviación rompe sus ejemplos.
- La librealsense actual soporta Ubuntu 24.04 (kernels 6.x) para cámaras D4xx, pero eso **no** incluye el L515.

## Decisión de arquitectura (y por qué)

- **Contenedor congelado** con librealsense `v2.54.1` (candidata principal) y `realsense-ros` `4.51.1`. Respaldo: `v2.54.2` (soportada sin validar) o `v2.50.0` (la que Intel validó).
- **Backend RSUSB** (`-DFORCE_RSUSB_BACKEND=ON`): el contenedor comparte kernel con el host y no puede cargar módulos parchados; RSUSB trabaja en espacio de usuario. Si RSUSB falla con el L515, el plan B es el backend nativo con los parches de kernel **en el host** (requiere humano y `sudo`), y se registra como decisión.
- **Base del contenedor**: Ubuntu 22.04 + ROS2 Humble. Alternativa: Ubuntu 20.04 + Foxy, solo si Humble falla con el wrapper 4.51.1.
- **Puente**: el contenedor publica tópicos ROS2; el host con Ubuntu 24.04 (ROS2 Jazzy) los consume por DDS con `--network host`, mismo `ROS_DOMAIN_ID` y mismo `RMW_IMPLEMENTATION`. LiveKit e Isaac leen tópicos, nunca hablan con el L515 directo.

## VERIFICAR antes de usar

| Dato | Cómo verificarlo |
|---|---|
| Que existan los tags `v2.54.1`, `v2.54.2`, `v2.50.0` de librealsense | `git ls-remote --tags https://github.com/IntelRealSense/librealsense.git` (puede redirigir a la organización `realsenseai`) |
| Que exista el tag `4.51.1` de `realsense-ros` y qué distros soporta | `git ls-remote --tags https://github.com/IntelRealSense/realsense-ros.git` y leer su README en ese tag |
| IDs USB del L515 (se recuerdan `8086:0b64` y `8086:0b3d` para pre-producción) | `lsusb` con la cámara conectada. Solo cuenta lo que muestre el equipo real |
| Firmware del L515 1.5.8.1 o posterior | `rs-enumerate-devices -s` o `rs-fw-update -l` dentro del contenedor |
| Que Humble (contenedor) y Jazzy (host) intercambien `sensor_msgs/Image` por DDS | `ros2 topic echo --once` desde el host; si falla, usar `rmw_cyclonedds_cpp` en ambos |
| API actual del SDK Python de LiveKit (`livekit`, `livekit-api`) | Documentación oficial de LiveKit; ver `livekit-bridge.md` |
| Distro de ROS2 de la versión de Isaac ROS elegida | Documentación de Isaac ROS; ver `isaac.md` |
| Reglas `--device-cgroup-rule` para USB en tu Docker | `ls -l /dev/bus/usb` y `cat /proc/devices` (mayores 189 USB, 81 video4linux) |

## Límites (qué NO hace esta skill)

- No hace ingeniería inversa de firmware ni del protocolo USB. El L515 calcula la profundidad dentro de la cámara con firmware cerrado; el código abierto de librealsense ya implementa la comunicación con él. Si surge un hueco concreto que el código abierto no cubre, se detiene y se consulta al usuario; analizar firmware tiene además implicaciones de licencia que debe revisar alguien con conocimiento legal.
- No actualiza el firmware de la cámara: puede dejarla inservible o incompatible. Solo se lee la versión.
- No garantiza hardware: si el cable, el puerto o la cámara están dañados, el software no lo arregla.
- No mantiene nada por su cuenta: nadie vigila actualizaciones. Si el sistema cambia, hay que repetir la validación (Fase 3).
