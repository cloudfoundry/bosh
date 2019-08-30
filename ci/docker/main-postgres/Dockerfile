FROM bosh/main-base

ARG DB_VERSION

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update

RUN apt-get install -y \
	postgresql-$DB_VERSION \
	postgresql-client-$DB_VERSION \
	&& apt-get clean
