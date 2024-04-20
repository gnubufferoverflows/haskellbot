# Lambdabot Reloaded

This is a version of Lambdabot, but for Discord. It is setup as a Docker container so that one can easily deploy it. For now, the container has to be built from scratch, and you must hardcode the bot token in by replacing it in the `CMD` directive as the command line argument after `--`. The `token.txt` reader isn't currently working at the moment. Thanks Docker.

The original Lambdabot this was inspired from can be found here: https://wiki.haskell.org/Lambdabot
