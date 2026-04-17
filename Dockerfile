FROM cm2network/steamcmd:steam-trixie AS vanilla

LABEL maintainer="Richard Bates<richard.batesiii.dev@gmail.com>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

ENV GAME_INSTALL_DIR=/home/steam/Unturned \
    SERVER_ID=server \
    UPDATE_ON_START=false \
    WORKSHOP_FILE_IDS= \
    STEAMCMD_DIR=/home/steam/steamcmd \
    LDM_ENABLED=false \
    LDM_INSTALL_DIR=/opt/ldm

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "$GAME_INSTALL_DIR" "$LDM_INSTALL_DIR" \
    && chown -R steam:steam "$GAME_INSTALL_DIR" "$LDM_INSTALL_DIR"

COPY --chown=steam:steam init.sh /usr/local/bin/init.sh
RUN chmod 0755 /usr/local/bin/init.sh

EXPOSE 27015/tcp
EXPOSE 27015/udp
EXPOSE 27016/tcp
EXPOSE 27016/udp

VOLUME ["$GAME_INSTALL_DIR"]

USER steam
WORKDIR $STEAMCMD_DIR

ENTRYPOINT ["/usr/local/bin/init.sh"]

FROM vanilla AS ldm

ENV LDM_ENABLED=true \
    LDM_REPOSITORY=SmartlyDressedGames/Legally-Distinct-Missile \
    LDM_VERSION=v4.9.3.18

RUN set -eux; \
    asset_url="https://github.com/${LDM_REPOSITORY}/releases/download/${LDM_VERSION}/Rocket.Unturned.zip"; \
    curl -fsSL "$asset_url" -o /tmp/ldm.zip; \
    rm -rf "${LDM_INSTALL_DIR:?}/"*; \
    unzip -q /tmp/ldm.zip -d "$LDM_INSTALL_DIR"; \
    test -f "$LDM_INSTALL_DIR/Rocket.Unturned/Rocket.Unturned.module"; \
    rm -f /tmp/ldm.zip
