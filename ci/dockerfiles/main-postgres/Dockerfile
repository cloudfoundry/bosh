ARG BRANCH
FROM bosh/integration:${BRANCH}

ARG DB_VERSION

# To build all gems and install ruby
RUN apt update && apt -yq install \
    libmysqlclient-dev libpq-dev libsqlite3-dev

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt update

RUN DEBIAN_FRONTEND="noninteractive" apt-get install -y \
	postgresql-$DB_VERSION \
	postgresql-client-$DB_VERSION \
	&& apt clean

ENV PATH=$PATH:/usr/lib/postgresql/$DB_VERSION/bin

ADD trust_pg_hba.conf /tmp/pg_hba.conf
RUN cp /tmp/pg_hba.conf /etc/postgresql/$DB_VERSION/main/pg_hba.conf
RUN sed -i 's/port = 5433/port = 5432/g' /etc/postgresql/$DB_VERSION/main/postgresql.conf
