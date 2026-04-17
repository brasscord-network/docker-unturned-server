#!/usr/bin/env bash

cd "$GAME_INSTALL_DIR" || exit

ulimit -n 2048

export TERM=xterm

exec ./Unturned_Headless.x86_64 -logFile - -batchmode -nographics +secureserver/"$SERVER_NAME"
