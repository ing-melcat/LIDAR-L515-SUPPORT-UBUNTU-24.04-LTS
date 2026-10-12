# Conexión con Isaac

## Paso 0: aclarar cuál Isaac

"Isaac" puede ser dos cosas distintas. Pregunta al humano si no está en STATE.md.

- **Isaac ROS**: paquetes ROS2 acelerados por GPU de NVIDIA que corren en Jetson o en un PC con GPU, normalmente dentro de su propio Docker. Consume tópicos de cámara. **Esta es la que aplica a un sensor real como el L515.**
- **Isaac Sim**: simulador. No lee cámaras reales. Solo aplica si quieres simular un L515, y eso es otro proyecto (se necesitaría un modelo del sensor).

## Qué se sabe (confirmado)

La guía oficial de Isaac ROS para RealSense solo lista como soportadas la D455 y la D435i, y exige firmware 5.13.0.50, librealsense 2.55.1 y `realsense-ros` 4.51.1-isaac, advirtiendo que cualquier desviación rompe sus ejemplos. El L515 no está en esa lista y la 2.55.1 ya no lo soporta. **No instales esas versiones dentro del contenedor del L515**: son incompatibles con él.

## Estrategia

Aislar. El L515 vive en su contenedor congelado y publica tópicos estándar. Isaac ROS corre en su propio entorno y se **suscribe** a esos tópicos; nunca instala el driver del L515.

```
[L515] → contenedor congelado (Humble + librealsense 2.54.x) → tópicos ROS2
                                                                   │ DDS (--network host, mismo domain id)
                                          [entorno Isaac ROS] ←────┘  (solo suscribe)
```

## VERIFICAR (rol R6)

1. Qué distro de ROS2 usa la versión de Isaac ROS del humano (sus releases han usado Humble y distros posteriores). Si es distinta de Humble, confirma que el intercambio de mensajes estándar funciona por DDS, igual que en el puente al host.
2. Los nombres de tópicos que esperan los nodos de Isaac que quiera usar (por ejemplo, profundidad y `camera_info`) y la convención de `frame_id`. Se leen de la documentación de ese paquete, no se asumen.
3. Si los nombres no coinciden, usa **remapeos** en el launch de Isaac en lugar de tocar el contenedor del L515:
```bash
ros2 run <paquete> <nodo> --ros-args \
  -r depth:=/camera/camera/depth/image_rect_raw \
  -r camera_info:=/camera/camera/depth/camera_info
```
(los nombres a la izquierda dependen del nodo; confírmalos).

## Pruebas y criterio

1. Desde el entorno Isaac: `ros2 topic list` ve los tópicos del L515 y `ros2 topic hz` mide frecuencia.
2. Arranca un nodo de Isaac que consuma profundidad y confirma que produce salida.
3. Registra en `07_isaac.md` qué funcionó, qué no, y qué **no se probó**. No afirmes "compatible con Isaac"; afirma "tópicos del L515 consumidos por <nodo> en <versión>" con la evidencia.

Limitaciones a declarar: el L515 es LiDAR de estado sólido y sus imágenes de profundidad tienen características distintas a las de cámaras estéreo (D4xx); algunos nodos de Isaac están ajustados a otro tipo de sensor y pueden requerir cambiar parámetros.
