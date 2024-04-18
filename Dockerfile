 #escape=\
 FROM docker.io/alpine:3.14

 ARG TOKEN
 RUN set -ex; \
     \
     apk update; \
     apk add curl binutils-gold curl gcc g++ gmp-dev libc-dev libffi-dev make musl-dev ncurses-dev perl tar xz zlib-dev touch; \
     adduser -D bot;

USER bot
WORKDIR /home/bot
ENV PATH="$PATH:/home/bot/.cabal/bin:/home/bot/.ghcup/bin"
RUN set -ex; \
     \
     curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh; \
     cabal install --lib show simple-reflect QuickCheck pretty containers mtl array contravariant random; \
     cabal install --global mueval hoogle; \
     ghcup install ghc 9.6.2; ghcup set ghc 9.6.2; \
     ghcup install cabal 3.10.1.0; ghcup set cabal 3.10.1.0;

COPY app/ /home/bot/app/
COPY haskellbot.cabal /home/bot/
COPY CHANGELOG.md /home/bot/
COPY Def.hs /home/bot/
RUN "touch token"
RUN "echo \"$TOKEN\" > token"
RUN cabal build
CMD ["cabal", "run", "haskellbot", "--", "$(< /home/bot/token)"]
