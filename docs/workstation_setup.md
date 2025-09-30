# Development Mac Workstation Setup

## Assumptions

* We include examples using Homebrew here. Replace with your package manager of choice.
* You have cloned the project to `${HOME}/workspace/bosh/`
* You have installed the ruby version matching `.ruby-version`

## Steps

1. Bring homebrew index up-to-date

    `brew update`

2. Install mysql (needed by the mysql2 gem)

     ```bash
     brew install mysql
     brew services start mysql
     ```

3. Start and setup mysql (required for running integration tests with mysql)

     ```bash
     brew services start mysql
     ```

    - create mysql user: `root/password`
      i.e.: `alter user 'root'@'localhost' identified by 'password';`

4. Install postgresql (needed by the pg gem)

    `brew install postgresql`

5. Setup and Start postgresql (required for running integration tests with postgresql (default))

    The server does not use any password, the authentication method should be set to `trust` for all authentication methods in `pg_hba.conf`.

    * start postgres

        ```bash
        brew services start postgresql
        ```

    * create postgres user: `$USER/<no-password>` and a postgres DB for that user

        ```bash
        createuser -U $USER --superuser postgres
        createdb -U $USER
        ```

    * increase `max_connections` setting

        ```bash
        echo 'ALTER SYSTEM SET max_connections = 250' | psql
        brew services restart postgresql
        ```

6. Install the `bundler` gem

    `gem install bundler`

7. Install the gems needed to run BOSH

    ```bash
    cd ~/workspace/bosh/src
    git lfs pull
    bundle install
    ```

8. Download `bosh-agent` dependency:
   ```
   cd ~/workspace/bosh/src
   bundle exec rake spec:integration:download_bosh_agent
   ```

9. Install Java - required for some components in the BOSH ecosystem

    ```bash
    brew install temurin@17
    ```

## Issues

If you have trouble bundling, specifying an architecture has helped int he past

```
(sudo) env ARCHFLAGS="-arch $ARCH" gem install pg -v "${$VERSION_FROM_Gemfile.lock}
```
