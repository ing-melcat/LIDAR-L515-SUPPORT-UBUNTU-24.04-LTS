#!/usr/bin/env python3
"""Captura 60 frames de depth y color del L515 y mide FPS. Imprime PASS o FAIL."""
import sys, time
import pyrealsense2 as rs

ctx = rs.context()
devs = ctx.query_devices()
if len(devs) == 0:
    print("FAIL: no se detecta ningún dispositivo RealSense")
    sys.exit(2)

d = devs[0]
def info(k):
    return d.get_info(k) if d.supports(k) else "?"
print("Nombre:   ", info(rs.camera_info.name))
print("Serie:    ", info(rs.camera_info.serial_number))
print("Firmware: ", info(rs.camera_info.firmware_version))
print("USB:      ", info(rs.camera_info.usb_type_descriptor))
print("SDK:      ", rs.__version__)

pipe, cfg = rs.pipeline(), rs.config()
cfg.enable_stream(rs.stream.depth)   # perfil por defecto: evita pedir resoluciones no soportadas
cfg.enable_stream(rs.stream.color)
try:
    pipe.start(cfg)
except Exception as e:
    print(f"FAIL: no arrancó el streaming: {e}")
    sys.exit(3)

n_depth = n_color = 0
t0 = time.time()
try:
    while n_depth < 60 or n_color < 60:
        frames = pipe.wait_for_frames(5000)
        if frames.get_depth_frame():
            n_depth += 1
        if frames.get_color_frame():
            n_color += 1
        if time.time() - t0 > 30:
            print(f"FAIL: timeout (depth={n_depth}, color={n_color})")
            sys.exit(4)
except Exception as e:
    print(f"FAIL: error durante la captura: {e}")
    sys.exit(5)
finally:
    pipe.stop()

dt = time.time() - t0
print(f"Frames depth={n_depth} color={n_color} en {dt:.1f}s (~{n_depth/dt:.1f} FPS)")
print("PASS")
