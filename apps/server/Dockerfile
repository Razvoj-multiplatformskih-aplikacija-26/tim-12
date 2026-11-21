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
  '  - packages/contract' \
  '  - packages/mapping' \
  '  - apps/server' > pubspec.yaml
COPY pubspec.lock ./
COPY packages/domain/pubspec.yaml packages/domain/
COPY packages/contract/pubspec.yaml packages/contract/
COPY packages/mapping/pubspec.yaml packages/mapping/
COPY apps/server/pubspec.yaml apps/server/
RUN dart pub get

COPY packages/domain packages/domain
COPY packages/contract packages/contract
COPY packages/mapping packages/mapping
COPY apps/server apps/server
RUN dart compile exe apps/server/bin/server.dart -o /server

# Minimalna slika: samo izvrsni fajl i sistemske biblioteke koje mu trebaju.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /server /app/server
# Migracije se primenjuju pri pokretanju i citaju relativno od /app.
COPY apps/server/migrations /app/migrations
WORKDIR /app
EXPOSE 8080
CMD ["/app/server"]
