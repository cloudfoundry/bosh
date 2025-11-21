ARG BASE_IMAGE
FROM $BASE_IMAGE

ARG DB_VERSION

ENV DEBIAN_FRONTEND="noninteractive"
ENV PATH=${PATH}:"/usr/lib/postgresql/${DB_VERSION}/bin"

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

RUN sed -i 's/port = 5433/port = 5432/g' "/etc/postgresql/${DB_VERSION}/main/postgresql.conf"
