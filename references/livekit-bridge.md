# Puente ROS2 → LiveKit

## Diseño

LiveKit transporta video WebRTC; no entiende `sensor_msgs/Image`. El puente corre en el **host** (Ubuntu 24.04 con ROS2 Jazzy), se suscribe a un tópico de imagen del L515 y publica cada frame como un track de video en una sala.

- **Color**: se publica directo (`rgb8` o `bgr8`).
- **Depth**: es `16UC1` en milímetros. WebRTC no transporta 16 bits sin pérdida, así que se publica **solo para visualización**: se normaliza a 8 bits y se aplica un colormap. Si algo necesita la profundidad métrica real, debe leer el tópico ROS2, no el video.
- Los secretos solo entran por variables de entorno: `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`. Nunca en el código ni en archivos.

## VERIFICAR antes de escribir código

El SDK de LiveKit cambia. El rol R5 debe abrir la documentación oficial de LiveKit para Python y confirmar nombres actuales de: `rtc.Room`, `rtc.VideoSource`, `rtc.LocalVideoTrack`, `rtc.VideoFrame`, `rtc.VideoBufferType`, `api.AccessToken`, `api.VideoGrants`. El código de abajo refleja lo que se conocía al escribir esta skill; si algo no coincide, manda la documentación.

Instalación en el host (entorno virtual, no tocar el Python del sistema):
```bash
python3 -m venv ~/venvs/l515-livekit --system-site-packages
source ~/venvs/l515-livekit/bin/activate
pip install livekit livekit-api numpy opencv-python-headless
```
`--system-site-packages` permite usar `rclpy` de Jazzy dentro del venv.

## Prueba 1: sin cámara (frame sintético)

Antes de involucrar ROS2, confirma que LiveKit funciona.
```python
import asyncio, os, numpy as np
from livekit import rtc, api

W, H = 640, 480

async def main():
    url = os.environ["LIVEKIT_URL"]
    token = (api.AccessToken(os.environ["LIVEKIT_API_KEY"], os.environ["LIVEKIT_API_SECRET"])
             .with_identity("l515-bridge")
             .with_grants(api.VideoGrants(room_join=True, room="l515-test"))
             .to_jwt())
    room = rtc.Room()
    await room.connect(url, token)
    source = rtc.VideoSource(W, H)
    track = rtc.LocalVideoTrack.create_video_track("l515-test", source)
    await room.local_participant.publish_track(
        track, rtc.TrackPublishOptions(source=rtc.TrackSource.SOURCE_CAMERA))
    t = 0
    while True:
        img = np.zeros((H, W, 3), np.uint8)
        img[:, :, 0] = (t * 4) % 256          # franja que cambia con el tiempo
        frame = rtc.VideoFrame(W, H, rtc.VideoBufferType.RGB24, img.tobytes())
        source.capture_frame(frame)
        t += 1
        await asyncio.sleep(1 / 15)

asyncio.run(main())
```
Criterio: el humano abre la sala y ve el color cambiando.

## Prueba 2: puente real

Guarda como `l515_livekit_bridge.py` en el proyecto.
```python
import asyncio, os, threading
import numpy as np, cv2
import rclpy
from rclpy.node import Node
from rclpy.qos import qos_profile_sensor_data
from sensor_msgs.msg import Image
from livekit import rtc, api

TOPIC = os.environ.get("L515_TOPIC", "/camera/camera/color/image_raw")  # confirmar con ros2 topic list
ROOM = os.environ.get("LIVEKIT_ROOM", "l515")

def to_rgb(msg: Image) -> np.ndarray:
    buf = np.frombuffer(msg.data, np.uint8)
    if msg.encoding == "rgb8":
        return buf.reshape(msg.height, msg.width, 3)
    if msg.encoding == "bgr8":
        return buf.reshape(msg.height, msg.width, 3)[:, :, ::-1]
    if msg.encoding == "16UC1":                        # depth en mm, solo visual
        d = np.frombuffer(msg.data, np.uint16).reshape(msg.height, msg.width)
        d8 = cv2.convertScaleAbs(d, alpha=255.0 / 4000.0)   # recorta a ~4 m
        return cv2.cvtColor(cv2.applyColorMap(d8, cv2.COLORMAP_JET), cv2.COLOR_BGR2RGB)
    raise ValueError(f"encoding no soportado: {msg.encoding}")

class Bridge(Node):
    def __init__(self, push):
        super().__init__("l515_livekit_bridge")
        self.push = push
        self.create_subscription(Image, TOPIC, self.cb, qos_profile_sensor_data)
    def cb(self, msg):
        try:
            self.push(np.ascontiguousarray(to_rgb(msg)))
        except Exception as e:
            self.get_logger().error(str(e))

async def main():
    loop = asyncio.get_running_loop()
    token = (api.AccessToken(os.environ["LIVEKIT_API_KEY"], os.environ["LIVEKIT_API_SECRET"])
             .with_identity("l515-bridge")
             .with_grants(api.VideoGrants(room_join=True, room=ROOM)).to_jwt())
    room = rtc.Room()
    await room.connect(os.environ["LIVEKIT_URL"], token)
    state = {"source": None}

    def push(arr):
        h, w, _ = arr.shape
        def _send():
            if state["source"] is None:
                state["source"] = rtc.VideoSource(w, h)
                track = rtc.LocalVideoTrack.create_video_track("l515", state["source"])
                asyncio.ensure_future(room.local_participant.publish_track(
                    track, rtc.TrackPublishOptions(source=rtc.TrackSource.SOURCE_CAMERA)))
            state["source"].capture_frame(
                rtc.VideoFrame(w, h, rtc.VideoBufferType.RGB24, arr.tobytes()))
        loop.call_soon_threadsafe(_send)

    rclpy.init()
    node = Bridge(push)
    threading.Thread(target=rclpy.spin, args=(node,), daemon=True).start()
    await asyncio.Event().wait()

asyncio.run(main())
```
Notas para el agente:
- Si la resolución cambia a mitad de ejecución, hay que recrear el `VideoSource`. Este ejemplo asume resolución fija.
- Ejecuta una instancia por tópico (color y depth) con `L515_TOPIC` y `LIVEKIT_ROOM` distintos, o identidades distintas.
- Criterio de salida: el humano ve el video del L515 en la sala y confirma que el movimiento se refleja.
