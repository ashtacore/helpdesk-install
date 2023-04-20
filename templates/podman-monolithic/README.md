# The Unofficial Podman Template
Podman can intercept calls to the docker API, but only if docker has been installed to your computer. If you would prefer to not install docker, then I hope these modifications help you.

For the most part of have simply changed the word 'docker' to 'podman' in any docker commands. However Podman does not come with built in functionality for compose files, so I am using the python extension [podman-compose](https://github.com/containers/podman-compose). This extension replaces the 'docker compose' command with 'podman-compose'. I have corrected the compose commands in the set-up file, but make sure to use `podman-compose up -d` when continueing to the next step of SupportPal's installation. Podman-compose still uses 'docker-compose.yml' files, but as of version 1.0.6 does not seem to recognize override files. 

I have set the minimum required Podman version to 4.5.0 and the minimum version of podman-compose to 1.0.6 because that is what I used when creating this script. It will likely work with older versions.

This script was tested on Windows Server 2022 and Windows 11 both using Podman from within WSL. You shouldn't have issues on Linux, but if you do I'd be insterested to know about it.

## No HA Docker Template?
Sorry but my enviroment doesn't require that. However please read what I've wrote above about [podman-compose](https://github.com/containers/podman-compose) and good luck. 