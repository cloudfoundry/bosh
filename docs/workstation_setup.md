# Development Mac Workstation Setup

## Assumptions

* We include examples using Homebrew here. Replace with your package manager of choice.
* You have cloned the project to $HOME/workspace/bosh
* You have installed Ruby `3.0.2` or later

## Steps

1. Bring homebrew index up-to-date

    `brew update`

2. Install mysql (needed by the mysql2 gem)

  `brew install mysql`

3. Setup & Start mysql (required for running integration tests with mysql)
    - start mysql as root
    - create mysql user: root/password
      i.e.: `alter user 'root'@'localhost' identified by 'password';`

4. Install postgresql (needed by the pg gem)

    `brew install postgresql`

5. Setup and Start postgresql (required for running integration tests with postgresql (default))

    The server does not use any password, the authentication method should be set to `trust` for all authentication methods in `pg_hba.conf`.

    * start postgres

        ```
        ln -sfv /usr/local/opt/postgresql/*.plist ~/Library/LaunchAgents
        launchctl load ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist
        ```

    * create postgres user: $USER/\<no-password\>

        `createuser -U $USER --superuser postgres`

    * create postgres database

        `createdb -U $USER`

    * increase `max_connections` setting

        ```sh
        echo 'ALTER SYSTEM SET max_connections = 250' | psql
        # Restart postgres
        ## If you're using brew services to start and stop postgres
        brew services restart postgresql
        ## Otherwise, you can use launchctl directly
        launchctl stop homebrew.mxcl.postgresql
        launchctl start homebrew.mxcl.postgresql
        ```

6. Get Golang dependencies

    Install golint
    * `go install golang.org/x/lint/golint`

    Optional: Install direnv to keep your GOPATH correct when working with the bosh-agent submodule
    * `brew install direnv`
    * `cd <<bosh base dir>>`
    * direnv allow

7. Install Bundler gem

    `gem install bundler`

8. Install Java 8

    For certain components a java runtime is required. Currently java 8 is required, versions 9 and 10 are not supported at the moment.
    On MacOS you can do something like

    ```sh
    brew tap caskroom/versions
    brew cask install java8
    export JAVA_HOME=`/usr/libexec/java_home -v 1.8`
    ```

9. Bundle BOSH

    ```
    cd ~/workspace/bosh/src
    bundle install
    ```

    If ever you hit some compilation issues with the `thin` Gem
    about “implicit function declarations”, try installing it manually with
    the following compilation flag:

    ```
    gem install thin -v '1.7.2' -- --with-cflags="-Wno-error=implicit-function-declaration"
    ```

    If ever you hit some linker issues like “_ld: library not found
    for -lssl_” when installing the `mysql2` Gem, try installing it manually
    with the following linker flags:

    ```
    gem install mysql2 -v '0.5.3' -- --with-ldflags="-L/usr/local/opt/openssl@1.1/lib"
    ```

10. Download `bosh-agent` dependency:
    ```
    cd ~/workspace/bosh/src
    bundle exec rake spec:integration:download_bosh_agent
    ```

## Issues

If you have trouble bundling, you may have to install pg gem manually by specifying your architecture:

```
(sudo) env ARCHFLAGS="-arch x86_64" gem install pg -v '0.15.1'
```
