ARG BRANCH
FROM bosh/integration:${BRANCH}

# Install Dependencies
RUN echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections
RUN echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections
RUN apt-get update && apt-get -yq install \
    wget build-essential libmysqlclient-dev libpq-dev libsqlite3-dev git mysql-server locales
