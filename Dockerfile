# syntax=docker/dockerfile:1
FROM 1password/op:2.41.1 AS op

FROM ghcr.io/runatlantis/atlantis:v0.49.0

LABEL org.opencontainers.image.title="atlantis-op" \
      org.opencontainers.image.description="Atlantis with 1Password CLI: resolve op:// secret references via a service account or 1Password Connect" \
      org.opencontainers.image.source="https://github.com/aurimasniekis/docker-atlantis-op" \
      org.opencontainers.image.licenses="MIT"

USER root
# Pre-create the data dir so a mounted named volume inherits atlantis ownership.
RUN mkdir -p /home/atlantis/.atlantis /etc/atlantis \
 && chown -R atlantis:atlantis /home/atlantis/.atlantis
USER atlantis

COPY --from=op /usr/local/bin/op /usr/local/bin/op
COPY --chmod=0755 atlantis-op /usr/local/bin/atlantis-op

ENV ATLANTIS_DATA_DIR=/home/atlantis/.atlantis \
    OP_ENV_FILE=/etc/atlantis/atlantis.env.op

# docker-entrypoint.sh (dumb-init) -> atlantis-op (op run) -> atlantis server
ENTRYPOINT ["docker-entrypoint.sh", "atlantis-op"]
CMD ["server"]
