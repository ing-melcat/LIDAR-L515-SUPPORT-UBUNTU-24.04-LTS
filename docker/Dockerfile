# L515 congelado: librealsense + realsense-ros fijos sobre ROS2 Humble (Ubuntu 22.04).
# Las versiones son ARG: R1 debe confirmarlas (references/facts.md) antes de construir.
FROM ros:humble-ros-base

ARG LRS_REPO=https://github.com/IntelRealSense/librealsense.git
ARG LRS_TAG=v2.54.1
ARG RS_ROS_REPO=https://github.com/IntelRealSense/realsense-ros.git
ARG RS_ROS_TAG=4.51.1
ARG JOBS=4

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake build-essential pkg-config ca-certificates \
    libssl-dev libusb-1.0-0-dev libudev-dev udev \
    python3-dev python3-pip python3-numpy python3-colcon-common-extensions \
    ros-humble-rmw-cyclonedds-cpp usbutils libx11-dev libxcursor-dev libxrandr-dev libxinerama-dev libxi-dev libgl1-mesa-dev \
 && rm -rf /var/lib/apt/lists/*

# librealsense con backend RSUSB (sin módulos de kernel parchados: el contenedor usa el kernel del host)
RUN git clone --branch ${LRS_TAG} --depth 1 ${LRS_REPO} /opt/librealsense \
 && cd /opt/librealsense && mkdir build && cd build \
 && cmake .. -DCMAKE_BUILD_TYPE=Release \
      -DFORCE_RSUSB_BACKEND=ON \
      -DBUILD_PYTHON_BINDINGS=ON -DPYTHON_EXECUTABLE=$(which python3) \
      -DBUILD_EXAMPLES=ON -DBUILD_GRAPHICAL_EXAMPLES=OFF \
 && make -j${JOBS} && make install && ldconfig

# Wrapper ROS2 fijado
RUN mkdir -p /opt/ws/src && cd /opt/ws/src \
 && git clone --branch ${RS_ROS_TAG} --depth 1 ${RS_ROS_REPO} realsense-ros
RUN apt-get update && cd /opt/ws \
 && . /opt/ros/humble/setup.sh \
 && rosdep update --rosdistro humble || true \
 && rosdep install -i --from-path src --rosdistro humble -y --skip-keys=librealsense2 \
 && colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release \
 && rm -rf /var/lib/apt/lists/*

ENV LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH}
ENV PYTHONPATH=/usr/local/lib:/usr/local/OFF:${PYTHONPATH}
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ENV ROS_DOMAIN_ID=42
RUN echo "source /opt/ros/humble/setup.bash && source /opt/ws/install/setup.bash" >> /root/.bashrc
WORKDIR /opt/ws
CMD ["bash"]
