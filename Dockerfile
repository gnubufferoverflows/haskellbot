 #escape=\
 FROM docker.io/alpine:3.14

 RUN set -ex; \
     \
     apk update; \
     apk add curl binutils-gold curl gcc g++ gmp-dev libc-dev libffi-dev make musl-dev ncurses-dev perl tar xz zlib-dev; \
     adduser -D bot;

USER bot
WORKDIR /home/bot
ENV PATH="$PATH:/home/bot/.cabal/bin:/home/bot/.ghcup/bin"
RUN set -ex; \
     \
     curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh; \
     cabal install -O2 --lib show simple-reflect QuickCheck pretty containers mtl array contravariant random logict transformers tardis; \
     cabal install -O2 --global mueval; \
     cabal install --global hoogle; \
     ghcup install cabal 3.10.1.0; ghcup set cabal 3.10.1.0;

COPY app/ /home/bot/app/
COPY haskellbot.cabal /home/bot/
COPY CHANGELOG.md /home/bot/
COPY Def.hs /home/bot/
RUN cabal -O2 build
RUN hoogle generate
CMD ["sh", "-c","cabal run -O2 haskellbot -- $TOKEN"]
