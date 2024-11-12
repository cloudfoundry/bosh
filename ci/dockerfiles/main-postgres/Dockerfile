ARG BRANCH
FROM bosh/integration:${BRANCH}

ARG DB_VERSION

ENV DEBIAN_FRONTEND="noninteractive"
ENV PATH=${PATH}:/usr/lib/postgresql/${DB_VERSION}/bin

RUN echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list \
    && curl -sL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      | gpg --dearmor > /etc/apt/trusted.gpg.d/postgres-ACCC4CF8.gpg \
    && apt-get update \
    && apt-get install -y \
        libmysqlclient-dev \
        libpq-dev \
        libsqlite3-dev \
        "postgresql-${DB_VERSION}" \
        "postgresql-client-${DB_VERSION}"

COPY <<PG_HBA_CONF "/etc/postgresql/${DB_VERSION}/main/pg_hba.conf"
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             postgres                                peer
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            md5
host    replication     all             ::1/128                 md5
PG_HBA_CONF

RUN sed -i 's/port = 5433/port = 5432/g' "/etc/postgresql/${DB_VERSION}/main/postgresql.conf"
