# Contributing to BOSH

When contributing a pull request, be sure to submit your pull request against the [**master**](https://github.com/cloudfoundry/bosh/tree/master) branch. See [Pull Request Workflow](docs/pull_request_workflow.md) for futher details.

## Contributor License Agreement

Follow these steps to make a contribution to any of CF open source repositories:

1. Ensure that you have completed our CLA Agreement for
   [individuals](http://cloudfoundry.org/pdfs/CFF_Individual_CLA.pdf) or
   [corporations](http://cloudfoundry.org/pdfs/CFF_Corporate_CLA.pdf).

1. Set your name and email (these should match the information on your submitted CLA)

        git config --global user.name "Firstname Lastname"
        git config --global user.email "your_email@example.com"
       
## Set up a workstation for development
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

1. See [development docs](docs/README.md) to start contributing to BOSH.

## Creating a Local Development Release

1. Run `bundle exec rake release:create_dev_release`.

2. If you need a tarball release from this then you can run `bundle exec bosh create release --with-tarball /path/to/yaml/made/in/previous/step.yml`.
