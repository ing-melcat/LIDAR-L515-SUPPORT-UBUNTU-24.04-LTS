# Roles y prompts

Cada rol es un agente independiente (o un papel que juegas en secuencia en Modo B). Todos comparten estas reglas: lee `SKILL.md` y `references/facts.md` primero, trabaja solo dentro de `workspace/`, escribe tu reporte en `workspace/handoffs/` con la plantilla de abajo, no toques archivos de otros roles y, si te bloqueas, escribe el bloqueo en tu reporte en vez de improvisar.

## Plantilla de handoff (obligatoria)

```markdown
# Handoff: <rol> — <fecha y hora>
## Estado: COMPLETO | BLOQUEADO | PARCIAL
## Qué hice (comandos exactos, en orden)
## Resultados (salidas relevantes pegadas tal cual, sin resumir)
## Decisiones tomadas y por qué
## Cosas que NO pude verificar
## Qué necesita el siguiente rol
## Si estoy bloqueado: qué intenté (mínimo 2 intentos distintos) y qué necesito del humano
```

## Orquestador

Misión: coordinar. Pasos:
1. Fase 0: crea `workspace/{handoffs,inbox,logs}`, copia `assets/STATE.template.md` a `workspace/STATE.md`, haz el intake.
2. Antes de lanzar un rol, escribe en STATE.md `FASE N EN CURSO` y quién la ejecuta.
3. Al recibir un handoff, **compruébalo contra el criterio de salida de la fase** (tabla en SKILL.md). Si el reporte dice COMPLETO pero faltan pruebas, devuélvelo.
4. Nunca aceptes "debería funcionar". Exige la salida real del comando.
5. Si hay `ESPERANDO HUMANO`, no avances más allá de esa compuerta.

## R0 Reconocimiento (host)

Misión: describir el host sin modificar nada.
- Ejecuta `scripts/host_recon.sh` y guarda su salida completa en `handoffs/01_host.md`.
- Anota: versión de Ubuntu, kernel, arquitectura, si hay Docker y si el usuario puede usarlo sin sudo, si hay ROS2 instalado y cuál, puertos USB 3, y si la cámara ya aparece en `lsusb`.
- No instales nada. Si falta Docker, lista lo que falta como compuerta humana.

## R1 Investigador

Misión: confirmar los datos de `facts.md` marcados VERIFICAR con fuentes reales.
- Para cada tag, ejecuta `git ls-remote` y pega el resultado.
- Lee el README de `realsense-ros` en el tag 4.51.1 y anota distros soportadas y dependencias de `rosdep`.
- Busca en la documentación oficial de LiveKit el método actual para publicar video desde Python y anota la URL y fecha.
- Busca en la documentación de Isaac ROS la distro de ROS2 y los nombres de tópicos que esperan sus nodos de profundidad.
- Entrega una tabla: dato, valor confirmado, URL, fecha de consulta. Si algo no se puede confirmar, escribe NO CONFIRMADO. No rellenes.

## R2 Constructor

Misión: dejar una imagen Docker que compile y detecte el SDK.
- Parte de `assets/Dockerfile.l515`. Sustituye los `ARG` por las versiones que confirmó R1.
- Construye con `docker build -t l515-ros:$(date +%Y%m%d) -f Dockerfile.l515 .` y guarda el log completo en `workspace/logs/build.log`.
- Si falla: arregla una cosa a la vez, anota cada cambio. Al segundo fallo igual, pasa a BLOQUEADO con logs.
- Verifica dentro del contenedor: `rs-enumerate-devices --version`, `python3 -c "import pyrealsense2 as rs; print(rs.__version__)"`, `ros2 pkg list | grep realsense`.

## R3 Validador

Misión: demostrar con la cámara real que funciona.
- Pide al humano conectar la cámara a un puerto USB 3 con un cable bueno (compuerta humana).
- Corre `assets/run_container.sh` y dentro `rs-enumerate-devices -s`.
- Corre `python3 scripts/validate_camera.py` (captura 60 frames y mide FPS).
- Lanza el wrapper y mide: `bash scripts/check_ros_topics.sh`.
- Entrega la salida cruda. Un "se ve bien" sin logs no cuenta.

## R4 Puente host

Misión: que el host Ubuntu 24.04 vea los tópicos.
- Fija `ROS_DOMAIN_ID` y `RMW_IMPLEMENTATION` iguales en contenedor y host y regístralos.
- Desde el host (Jazzy): `ros2 topic list`, `ros2 topic hz <depth>`, `ros2 topic echo --once <camera_info>`.
- Si el host no ve nada: revisa que el contenedor use `--network host`, firewall, y prueba con `rmw_cyclonedds_cpp` en ambos lados.

## R5 LiveKit

Misión: publicar video del L515 a LiveKit. Sigue `references/livekit-bridge.md`.
- Pide al humano: URL de LiveKit, nombre de sala, y que exporte `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` en su shell. **Jamás** escribas esos valores en un archivo.
- Valida primero con una imagen de prueba sintética antes de conectar la cámara.
- Criterio: el humano ve el track en la sala.

## R6 Isaac

Misión: conectar los tópicos a Isaac. Sigue `references/isaac.md`. Primero aclara cuál Isaac es. No prometas compatibilidad oficial: documenta qué se probó y qué no.

## R7 Congelador

Misión: dejar todo reproducible.
- Ejecuta `scripts/freeze_image.sh` y registra el checksum.
- Genera `versions.lock` con: SO y kernel del host, versión de Docker, tags de librealsense y wrapper, firmware de la cámara, ROS_DOMAIN_ID, RMW, imagen y checksum.
- Escribe `GUIA_REPRODUCCION.md`: cómo restaurar la imagen y volver a levantar todo en una máquina limpia, con comandos exactos.
- Anota qué NO debe actualizarse sin repetir la Fase 3.

## R8 Revisor

Misión: buscar lo que los demás no vieron. No ejecutes cambios; solo reporta.
- Revisa cada handoff buscando afirmaciones sin evidencia.
- Prueba la guía de reproducción leyéndola como alguien que no conoce el proyecto: ¿falta algún paso o variable?
- Busca secretos filtrados: `grep -rniE "api[_-]?key|secret|token" workspace/ assets/` y reporta cualquier coincidencia real.
- Lista bloqueantes y recomendaciones por separado.
