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

Get Golang:
* `brew install go`
