import asyncio, os, threading
import numpy as np, cv2
import rclpy
from rclpy.node import Node
from rclpy.qos import qos_profile_sensor_data
from sensor_msgs.msg import Image
from livekit import rtc, api

TOPIC = os.environ.get("L515_TOPIC", "/camera/color/image_raw")
ROOM = os.environ.get("LIVEKIT_ROOM", "l515")

def to_rgb(msg: Image) -> np.ndarray:
    buf = np.frombuffer(msg.data, np.uint8)
    if msg.encoding == "rgb8":
        return buf.reshape(msg.height, msg.width, 3)
    if msg.encoding == "bgr8":
        return buf.reshape(msg.height, msg.width, 3)[:, :, ::-1]
    if msg.encoding == "16UC1":
        d = np.frombuffer(msg.data, np.uint16).reshape(msg.height, msg.width)
        d8 = cv2.convertScaleAbs(d, alpha=255.0 / 4000.0)
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
