# djaydev/HandBrake:latest

# Pull base build image.
FROM debian:10 AS builder

# Define software download URLs.
ARG HANDBRAKE_URL=https://github.com/HandBrake/HandBrake.git

# Set to 'max' to keep debug symbols.
ARG HANDBRAKE_DEBUG_MODE=none

# Define working directory.
WORKDIR /tmp

# Compile HandBrake, libva and Intel Media SDK.
RUN apt-get update && apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install \
    # build tools.
    curl build-essential autoconf libtool libtool-bin \
    m4 patch coreutils tar file git wget diffutils \
    # misc libraries
    libpciaccess-dev xz-utils libbz2-dev \
    # media libraries, media codecs, gtk
    libsamplerate-dev libass-dev libopus-dev libvpx-dev \
    libvorbis-dev gtk+3.0-dev libdbus-glib-1-dev libfribidi-dev \
    libnotify-dev libgudev-1.0-dev automake cmake \
    debhelper libspeex-dev libfontconfig1-dev libfreetype6-dev \
    libbluray-dev intltool libxml2-dev python python3 \
    libdvdnav-dev libdvdread-dev libgtk-3-dev meson \
    libjansson-dev liblzma-dev libappindicator-dev zlib1g-dev \
    libmp3lame-dev libogg-dev libglib2.0-dev ninja-build \
    libtheora-dev nasm yasm xterm libnuma-dev numactl libturbojpeg0-dev \
    libwebkit2gtk-4.0-dev libgstreamer-plugins-base1.0-dev \
    libgstreamer1.0-dev libpciaccess-dev linux-headers-amd64 libx264-dev -y

# Download HandBrake sources.
RUN echo "Downloading HandBrake sources..." && \
        git clone --single-branch --branch 1.3.x ${HANDBRAKE_URL} HandBrake && \
    # Download helper.
    echo "Downloading helpers..." && \
    curl -# -L -o /tmp/run_cmd https://raw.githubusercontent.com/jlesage/docker-mgmt-tools/master/run_cmd && \
    chmod +x /tmp/run_cmd && \
    # Compile HandBrake.
    echo "Compiling HandBrake..." && \
    cd HandBrake && \
    ./configure --prefix=/usr/local \
                --debug=$HANDBRAKE_DEBUG_MODE \
                --disable-gtk-update-checks \
                --enable-fdk-aac \
                --enable-x265 \
                --launch-jobs=$(nproc) \
                --launch \
                && \
    /tmp/run_cmd -i 600 -m "HandBrake still compiling..." make -j$(nproc) --directory=build install && \
    cd .. && \
    # Strip symbols.
        strip -s /usr/local/bin/ghb; \
        strip -s /usr/local/bin/HandBrakeCLI;

# Pull base image.
FROM jlesage/baseimage-gui:debian-10

WORKDIR /tmp

# Install dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends \
        # HandBrake dependencies
        libass9 libcairo2 libgtk-3-0 libgudev-1.0-0 libjansson4 libnotify4  \
        libtheora0 libvorbis0a libvorbisenc2 speex libopus0 libxml2 numactl \
        xz-utils git libdbus-glib-1-2 lame x264 gstreamer1.0-plugins-base \
        # For optical drive listing:
        lsscsi \
        # For watchfolder
        bash \
        coreutils \
        yad \
        findutils \
        expect \
        tcl8.6 \
        wget -y && \
    # To read encrypted DVDs
    wget http://www.deb-multimedia.org/pool/main/libd/libdvdcss/libdvdcss2_1.4.2-dmo1_amd64.deb && \
    apt-get install ./libdvdcss2_1.4.2-dmo1_amd64.deb -y && \
    # install scripts and stuff from upstream Handbrake docker image
    git config --global http.sslVerify false && \
    git clone https://github.com/jlesage/docker-handbrake.git && \
    cp -r docker-handbrake/rootfs/* / && \
    # Cleanup
    apt-get remove wget git -y && \
    apt-get autoremove -y && \
    apt-get autoclean -y && \
    apt-get clean -y && \
    apt-get purge -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Adjust the openbox config.
RUN \
    # Maximize only the main/initial window.
    sed-patch 's/<application type="normal">/<application type="normal" title="HandBrake">/' \
        /etc/xdg/openbox/rc.xml && \
    # Make sure the main window is always in the background.
    sed-patch '/<application type="normal" title="HandBrake">/a \    <layer>below</layer>' \
        /etc/xdg/openbox/rc.xml

# Generate and install favicons.
RUN \
    apt-get update && \
    APP_ICON_URL=https://raw.githubusercontent.com/jlesage/docker-templates/master/jlesage/images/handbrake-icon.png && \
    install_app_icon.sh "$APP_ICON_URL" && \
    apt-get autoremove -y && \
    apt-get autoclean -y && \
    apt-get clean -y && \
    apt-get purge -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy HandBrake from base build image.
COPY --from=builder /usr/local /usr

# Set environment variables.
ENV APP_NAME="HandBrake" \
    AUTOMATED_CONVERSION_PRESET="Very Fast 1080p30" \
    AUTOMATED_CONVERSION_FORMAT="mkv" \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all

# Define mountable directories.
VOLUME ["/config"]
VOLUME ["/storage"]
VOLUME ["/output"]
VOLUME ["/watch"]
