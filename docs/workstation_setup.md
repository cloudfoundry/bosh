# Development Mac workstation setup

## Assumptions

* We include examples using Homebrew here. Replace with your package manager of choice.
* You have cloned the project to $HOME/workspace/bosh

## Steps

1. Bring homebrew index up-to-date

    `brew update`

2. Install mysql (needed by the mysql2 gem)

  `brew install mysql`

3. Setup & Start mysql (required for running integration tests with mysql)
    - start mysql as root
    - create mysql user: root/password

4. Install postgresql (needed by the pg gem)

    `brew install postgresql`

5. Setup and Start postgresql (required for running integration tests with postgresql (default))
    * start postgres

        ```
        ln -sfv /usr/local/opt/postgresql/*.plist ~/Library/LaunchAgents
        launchctl load ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist
        ```

    * create postgres user: $USER/\<no-password\>

        `createuser -U $USER --superuser postgres`
    * create postgres database

        `createdb -U $USER`

6. Get redis

    `brew install redis`

7. Get Golang 1.3.3: As homebrew has a golang version >1.3.3 as current version, we need to install the `homebrew versions` command to check the correct git revision of golang 1.3.3
    * `brew tap homebrew/boneyard`
    * `brew versions go` and get the revision for version 1.3.3
    * `cd /usr/local/Library/Formula/`
    * `git checkout <revision> go.rb`
    * `brew install go`

    Install vet and golint
    * `go get code.google.com/p/go.tools/cmd/vet`
    * `go get -u github.com/golang/lint/golint`

8. Install Bundler gem

    `gem install bundler`

9. Bundle BOSH

    ```
    cd ~/workspace/bosh
    bundle install
    ```

## Issues

If you have trouble bundling, you may have to install pg gem manually by specifying your architecture:
* `(sudo) env ARCHFLAGS="-arch x86_64" gem install pg -v '0.15.1'`
