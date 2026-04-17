FROM cm2network/steamcmd:steam-trixie

LABEL maintainer="Richard Bates<richard.batesiii.dev@gmail.com>"

ARG PUID 1000
ARG PGID 1000

ENV GAME_INSTALL_DIR=/home/steam/Unturned
ENV GAME_ID=1110390
ENV SERVER_NAME=server
ENV STEAM_USERNAME=anonymous
ENV STEAMCMD_DIR=/home/steam/steamcmd

EXPOSE 27015
EXPOSE 27016

VOLUME ["$GAME_INSTALL_DIR"]

USER steam
WORKDIR $STEAMCMD_DIR

# Install Unturned
RUN mkdir -p $GAME_INSTALL_DIR
RUN bash ./steamcmd.sh +force_install_dir $GAME_INSTALL_DIR +login $STEAM_USERNAME $STEAM_PASSWORD $STEAM_GUARD_TOKEN $STEAM_CMD_ARGS +@sSteamCmdForcePlatformBitness 64 +app_update $GAME_ID +quit

COPY init.sh .

ENTRYPOINT ["./init.sh"]
