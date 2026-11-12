# Gradi server iz korena repozitorijuma (vidi docker-compose.yml).
#
# Koren workspace-a nabraja i Flutter aplikacije, a u ovoj slici nema
# Flutter SDK-a — zato se pravi suzeni koren sa samo onim sto server koristi.
# Nov paket koji server uvozi dodaje se i ovde (COPY + workspace lista).
FROM dart:3.13 AS build
WORKDIR /repo

RUN printf '%s\n' \
  'name: radioroom_workspace' \
  'environment:' \
  '  sdk: ^3.6.0' \
  'workspace:' \
  '  - packages/domain' \
  '  - apps/server' > pubspec.yaml
COPY pubspec.lock ./
COPY packages/domain/pubspec.yaml packages/domain/
COPY apps/server/pubspec.yaml apps/server/
RUN dart pub get

COPY packages/domain packages/domain
COPY apps/server apps/server
RUN dart compile exe apps/server/bin/server.dart -o /server

# Minimalna slika: samo izvrsni fajl i sistemske biblioteke koje mu trebaju.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /server /app/server
EXPOSE 8080
CMD ["/app/server"]
