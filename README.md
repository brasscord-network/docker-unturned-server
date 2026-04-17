# Unturned-Docker

This project is an updated and maintained docker repository for Unturned.

## Getting Started

The image has not been published anywhere yet, so you can pull the repository and build the image yourself.
There is a docker-compose included to help guide you.

Alternatively you build with the compose file.

`
docker compose -f docker-compose.yml up --build -d
`

## Server Type

The default setup only supports Vanilla Unturned. I have plans to include support for LDM and Built-in Workshop Support.

## Building

To build, use `docker build . -t unturned:latest`.

## Credits

This project was originally forked from the ImperialPlugins/unturned-docker repository.
Credit to the original maintainer of the project and developer of Rocketmod Trojaner.
Credit to the CM2 team for the base STEAMCMD docker image.
