# Development Mac Workstation Setup

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
      i.e.: `alter user 'root'@'localhost' identified by 'password';`

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

6. Get Golang 1.3.3: As homebrew has a golang version >1.3.3 as current version, we need to install the `homebrew versions` command to check the correct git revision of golang 1.3.3
    * `brew tap homebrew/boneyard`
    * `brew versions go` and get the revision for version 1.3.3
    * `cd /usr/local/Library/Formula/`
    * `git checkout <revision> go.rb`
    * `brew install go`

    Install vet and golint
    * `go get code.google.com/p/go.tools/cmd/vet`
    * `go get -u github.com/golang/lint/golint`

    Optional: Install direnv to keep your GOPATH correct when working with the bosh-agent submodule
    * `brew install direnv`
    * `cd <<bosh base dir>>`
    * direnv allow

7. Install Bundler gem

    `gem install bundler`

8. Bundle BOSH

    ```
    cd ~/workspace/bosh/src
    bundle install
    ```
9. Special instructions for nginx on  Mac

    Before running `rake spec:integration:install_dependencies`, modify the nginx packaging script to fix compilation on OSX.
    
    ```
    diff --git a/packages/nginx/packaging b/packages/nginx/packaging
    index 007e408a5..cc8956efe 100755
    --- a/packages/nginx/packaging
    +++ b/packages/nginx/packaging
    @@ -27,7 +27,9 @@ pushd nginx-1.12.1
             --add-module=../headers-more-nginx-module-0.30 \
             --with-http_ssl_module \
             --with-http_dav_module \
    -    --add-module=../nginx-upload-module-2.2
    +    --add-module=../nginx-upload-module-2.2 \
    +    --with-ld-opt="-L/usr/local/opt/openssl/lib" \
    +    --with-cc-opt="-I/usr/local/opt/openssl/include"
    
         make
         make install
    ```

## Issues

If you have trouble bundling, you may have to install pg gem manually by specifying your architecture:

```
(sudo) env ARCHFLAGS="-arch x86_64" gem install pg -v '0.15.1'
```

## Notes

### Custom bosh-cli

To use a custom go-cli in integration tests change `gobosh` in  `src/spec/gocli/support/bosh_go_cli_runner.rb`.

### Special instructions for nginx on  Mac

    Before running `rake spec:integration:install_dependencies`, modify the nginx packaging script to fix compilation on OSX.

    ```
    diff --git a/packages/nginx/packaging b/packages/nginx/packaging
    index 007e408a5..cc8956efe 100755
    --- a/packages/nginx/packaging
    +++ b/packages/nginx/packaging
    @@ -27,7 +27,9 @@ pushd nginx-1.12.1
             --add-module=../headers-more-nginx-module-0.30 \
             --with-http_ssl_module \
             --with-http_dav_module \
    -    --add-module=../nginx-upload-module-2.2
    +    --add-module=../nginx-upload-module-2.2 \
    +    --with-ld-opt="-L/usr/local/opt/openssl/lib" \
    +    --with-cc-opt="-I/usr/local/opt/openssl/include"

         make
         make install
    ```

### Cleaning the sandbox cache manually

Preparing the sandbox for integration tests caches dependencies like nginx. 
To force a recompilation either delete the complete `src/tmp` folder or just the 'work' folder:

```
bosh/src$ rm -fr tmp/integration-nginx-work/
```  

### Running integration test databases in docker

Instead of installing MySQL and PostgreSQL locally use `docker-compose` to spin up containers:

```
cd docs
docker-compose up
```
