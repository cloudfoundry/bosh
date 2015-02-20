# Set up a workstation for development

We assume you can install packages (brew, apt-get, or equivalent). We include Mac examples here, replace with your package manager of choice.

Bring homebrew index up-to-date:
* `brew update`

Get mysql libraries (needed by the mysql2 gem):
* `brew install mysql`

Get postgresql libraries (needed by the pg gem):
* `brew install postgresql`

Install pg gem manually by specifying your architecture:
* `(sudo) env ARCHFLAGS="-arch x86_64" gem install pg -v '0.15.1'`
 
Get redis:
* `brew install redis`

Get Golang 1.3.3:
As homebrew has a golang version >1.3.3 as current version, we need to install the `homebrew versions` command to check the correct git revision of golang 1.3.3
* `brew tap homebrew/boneyard`
* `brew versions go` and get the revision for version 1.3.3
* `cd /usr/local/Library/Formula/`
* `git checkout <revision> go.rb`
* `brew install go`
 
Install vet and golint
* `go get code.google.com/p/go.tools/cmd/vet`
* `go get -u github.com/golang/lint/golint`
