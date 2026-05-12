FROM renku/renkulab-vnc:3.11-5423b62

USER root

RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    libfontconfig1 \
    libxrender1 \
    libdbus-1-3 \
    libxkbcommon-x11-0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-xinerama0 \
    libxcb-cursor0 \
    && rm -rf /var/lib/apt/lists/*

RUN pip install "napari[all]==0.5.4" napari-sediment pyqt5

# Re-register VNC with jupyter-server-proxy
RUN printf 'c.ServerProxy.servers = {\n    "vnc": {\n        "command": [\n            "websockify", "-v",\n            "--web", "/opt/noVNC-1.1.0",\n            "--heartbeat", "30",\n            "5901",\n            "--unix-target", "/home/jovyan/.vnc/socket",\n            "--",\n            "vncserver", "-verbose",\n            "-xstartup", "dbus-launch xfce4-session",\n            "-geometry", "1024x768",\n            "-SecurityTypes", "None",\n            "-rfbunixpath", "/home/jovyan/.vnc/socket",\n            "-fg", ":1"\n        ],\n        "port": 5901,\n        "timeout": 30,\n        "new_browser_tab": False,\n        "launcher_entry": {\n            "title": "Desktop",\n            "enabled": True\n        }\n    }\n}\n' >> /etc/jupyter/jupyter_server_config.py

# Pre-start VNC on session startup
RUN printf '\n# Start VNC server early so it is ready when the session opens\nwebsockify -v --web /opt/noVNC-1.1.0 --heartbeat 30 5901 --unix-target /home/jovyan/.vnc/socket -- vncserver -verbose -xstartup "dbus-launch xfce4-session" -geometry 1024x768 -SecurityTypes None -rfbunixpath /home/jovyan/.vnc/socket -fg :1 &\nsleep 5\n' >> /post-init.sh

# Make /vnc/ redirect to vnc_renku.html
RUN printf '<html><head><meta http-equiv="refresh" content="0; url=vnc_renku.html"></head></html>' \
    > /opt/noVNC-1.1.0/index.html

# Fix cache permissions
RUN mkdir -p /home/jovyan/.cache/napari && \
    chown -R ${NB_USER}:${NB_GID} /home/jovyan/.cache

# Create a launcher script
RUN printf '#!/bin/bash\nexport DISPLAY=:1\nexport LIBGL_ALWAYS_SOFTWARE=1\nexport PYOPENGL_PLATFORM=egl\nexport NUMBA_CACHE_DIR=/tmp/numba_cache\nnapari\n' > /usr/local/bin/launch_napari.sh && \
    chmod +x /usr/local/bin/launch_napari.sh

# Create a desktop icon
RUN mkdir -p /home/jovyan/Desktop && \
    printf '[Desktop Entry]\nVersion=1.0\nType=Application\nName=Napari\nComment=Launch Napari\nExec=/usr/local/bin/launch_napari.sh\nIcon=applications-science\nTerminal=false\nCategories=Science;\n' \
    > /home/jovyan/Desktop/napari.desktop && \
    chmod +x /home/jovyan/Desktop/napari.desktop && \
    chown -R ${NB_USER}:${NB_GID} /home/jovyan/Desktop

USER ${NB_USER}