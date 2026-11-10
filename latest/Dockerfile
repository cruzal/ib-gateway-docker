##############################################################################
# Setup Stage: install apps
#
# This is a dedicated stage so that donwload archives don't end up on
# production image and consume unnecessary space.
##############################################################################

# hadolint global ignore=DL3008,DL4006
FROM ubuntu:26.04 AS setup

ENV IB_GATEWAY_VERSION=10.51.1e
ENV IB_GATEWAY_CHANNEL=latest
ENV IBC_VERSION=3.24.2
ARG DEBIAN_FRONTEND=noninteractive
ARG IB_GATEWAY_REPO="https://github.com/gnzsnz/ib-gateway-docker"
ARG IBC_FILE="IBCLinux-${IBC_VERSION}.zip"
ARG IBC_REPO="https://github.com/IbcAlpha/IBC"
ARG IBC_URL="${IBC_REPO}/releases/download/${IBC_VERSION}/${IBC_FILE}"
# IBC publishes no checksum; this one was taken from the 3.24.2 release asset.
# A new IBC_VERSION needs a new IBC_SHA256, or the build stops here.
ARG IBC_SHA256=cc097ca1dfa75413a5fbe02e4743050af15f3308eb6a97c769b3cff9850c80c5

WORKDIR /tmp/setup

# Installer checksums pinned in this repo (build/installer.sha256). The .sha256 file
# published next to the installer comes from the same place as the installer, so it
# only catches a broken download; this pin also catches a swapped release asset.
# A new IB_GATEWAY_VERSION needs its two lines added there.
COPY ./build/installer.sha256 /tmp/setup/installer.sha256

# Prepare system
RUN apt-get update -y && \
  apt-get install --no-install-recommends --yes \
  curl ca-certificates unzip && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  if [ "$(uname -m)" = "aarch64" ]; then \
     ARCH="arm" ; \
  else \
     ARCH="x64" ; \
  fi && \
  IB_GATEWAY_FILE="ibgateway-${IB_GATEWAY_VERSION}-standalone-linux-${ARCH}.sh" && \
  IB_GATEWAY_URL="${IB_GATEWAY_REPO}/releases/download/ibgateway-${IB_GATEWAY_CHANNEL}%40${IB_GATEWAY_VERSION}/${IB_GATEWAY_FILE}" && \
# Install IB Gateway
# Use this instead of "RUN curl .." to install a local file:
#COPY ibgateway-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh .
  curl -sSOL "${IB_GATEWAY_URL}" && \
  curl -sSOL "${IB_GATEWAY_URL}.sha256" && \
  sha256sum --check "./${IB_GATEWAY_FILE}.sha256" &&\
  grep -q " ${IB_GATEWAY_FILE}$" /tmp/setup/installer.sha256 && \
  grep " ${IB_GATEWAY_FILE}$" /tmp/setup/installer.sha256 | sha256sum --check - && \
  chmod a+x "./${IB_GATEWAY_FILE}" && \
  "./${IB_GATEWAY_FILE}" -q -dir "/root/Jts/ibgateway/${IB_GATEWAY_VERSION}" && \
  if [ -d "/root/Jts/ibgateway/${IB_GATEWAY_VERSION}/jre" ]; then \
    echo "/home/ibgateway/Jts/ibgateway/${IB_GATEWAY_VERSION}/jre" > "/root/Jts/ibgateway/${IB_GATEWAY_VERSION}/.install4j/inst_jre.cfg" ; \
  fi && \
  # Install IBC
  curl -sSOL "${IBC_URL}" && \
  echo "${IBC_SHA256}  ./${IBC_FILE}" | sha256sum --check - && \
  mkdir /root/ibc && \
  unzip "./${IBC_FILE}" -d /root/ibc && \
  chmod -R u+x /root/ibc/*.sh && \
  chmod -R u+x /root/ibc/scripts/*.sh

# Swap the CVE-flagged third-party jars IBKR bundles (see build/jar-overrides.txt)
COPY ./build /tmp/setup/build
RUN /tmp/setup/build/override-jars.sh \
  "/root/Jts/ibgateway/${IB_GATEWAY_VERSION}/jars" /tmp/setup/build/jar-overrides.txt

COPY ./config/ibgateway/jts.ini.tmpl /root/Jts/jts.ini.tmpl
COPY ./config/ibc/config.ini.tmpl /root/ibc/config.ini.tmpl

# Copy scripts
COPY ./scripts /root/scripts

##############################################################################
# Build Stage: build production image
##############################################################################

FROM ubuntu:26.04

ENV IB_GATEWAY_VERSION=10.51.1e
# IB Gateway user constants
ARG USER_ID="${USER_ID:-1000}"
ARG USER_GID="${USER_GID:-1000}"
# IBC env vars
ENV HOME=/home/ibgateway
ENV TWS_MAJOR_VRSN=${IB_GATEWAY_VERSION}
ENV TWS_PATH=${HOME}/Jts
ENV TWS_INI=jts.ini
ENV TWS_INI_TMPL=${TWS_INI}.tmpl
ENV IBC_PATH=${HOME}/ibc
ENV IBC_INI=${HOME}/ibc/config.ini
ENV IBC_INI_TMPL=${IBC_INI}.tmpl
ENV SCRIPT_PATH=${HOME}/scripts
ENV GATEWAY_OR_TWS=gateway
ARG DEBIAN_FRONTEND=noninteractive
# Bump to today's date to re-run `apt-get upgrade` on a builder that has this
# layer cached; the base tag alone doesn't change when Ubuntu ships a fix.
ARG APT_REFRESH=2026-11-10
# Copy files
COPY --from=setup /usr/local/ /usr/local/
COPY --chown=${USER_ID}:${USER_GID} --from=setup /root/ ${HOME}

# Prepare system
RUN apt-get update -y && \
  apt-get upgrade -y && \
  apt-get install --no-install-recommends --yes \
  gettext-base socat xvfb x11vnc ca-certificates \
  libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 libc6 libcairo2 libcups2 libdbus-1-3 \
  libdrm2 libexpat1 libgbm1 libglib2.0-0 libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 \
  libx11-6 libxcb1 libxcomposite1 libxdamage1 libxext6 libxfixes3 libxkbcommon0 \
  libxrandr2 fonts-liberation libasound2t64 libxtst6 xdg-utils && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  if id ubuntu; then \
    userdel -rf ubuntu \
  ;fi && \
  groupadd --gid ${USER_GID} ibgateway && \
  useradd -ms /bin/bash --uid ${USER_ID} --gid ${USER_GID} ibgateway && \
  chmod a+x ${SCRIPT_PATH}/*.sh && \
  mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

USER ${USER_ID}:${USER_GID}
WORKDIR ${HOME}

# Unhealthy while Gateway is not logged in (its API port only opens after login).
# Login takes 1-2 min, the nightly auto-restart about as long.
HEALTHCHECK --start-period=300s --interval=60s --timeout=5s --retries=5 \
  CMD ["/home/ibgateway/scripts/healthcheck.sh"]

# Start run script
CMD ["/home/ibgateway/scripts/run.sh"]

LABEL org.opencontainers.image.source=https://github.com/cruzal/ib-gateway-docker
LABEL org.opencontainers.image.base.name=https://github.com/gnzsnz/ib-gateway-docker
LABEL org.opencontainers.image.description="IB Gateway and IBC, hardened fork of gnzsnz/ib-gateway-docker"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version=${IB_GATEWAY_VERSION}
