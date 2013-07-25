# BOSH [![Build Status](https://travis-ci.org/cloudfoundry/bosh.png?branch=master)](https://travis-ci.org/cloudfoundry/bosh) [![Code Climate](https://codeclimate.com/github/cloudfoundry/bosh.png)](https://codeclimate.com/github/cloudfoundry/bosh) [![Dependency Status](https://gemnasium.com/cloudfoundry/bosh.png)](https://gemnasium.com/cloudfoundry/bosh)

Cloud Foundry BOSH is an open source tool chain for release engineering, deployment and lifecycle management of large scale distributed services. In this manual we describe the architecture, topology, configuration, and use of BOSH, as well as the structure and conventions used in packaging and deployment.

* BOSH Documentation: [http://docs.cloudfoundry.com/docs/running/deploying-cf/](http://docs.cloudfoundry.com/docs/running/deploying-cf/)

## Building and Installing BOSH gems from source

Sometimes it's helpful to have the latest BOSH gems before they are published to RubyGems. Here is an example how to build the latest from source. The gem builds require ruby 1.9.3-p327 currently, which you can see in the .ruby-version file. This example works on OSX.

    git clone https://github.com/cloudfoundry/bosh.git 
	cd bosh
	for i in bosh_common  blobstore_client bosh_cli ; do cd $i ; gem build *.gemspec  ; GEM=$(ls -1rt| tail -1 ) ; gem install $GEM; cd -; done

# Cloud Foundry Resources #

_Cloud Foundry Open Source Platform as a Service_

## Learn

Our documentation, currently a work in progress, is available here: [http://docs.cloudfoundry.com/](http://docs.cloudfoundry.com/)

## Ask Questions

Questions about the Cloud Foundry Open Source Project can be directed to our Google Groups.

* BOSH Developers: [https://groups.google.com/a/cloudfoundry.org/group/bosh-dev/topics](https://groups.google.com/a/cloudfoundry.org/group/bosh-dev/topics)
* BOSH Users:[https://groups.google.com/a/cloudfoundry.org/group/bosh-users/topics](https://groups.google.com/a/cloudfoundry.org/group/bosh-users/topics)
* VCAP (Cloud Foundry) Developers: [https://groups.google.com/a/cloudfoundry.org/group/vcap-dev/topics](https://groups.google.com/a/cloudfoundry.org/group/vcap-dev/topics)

## File a bug

Bugs can be filed using Github Issues within the various repositories of the [Cloud Foundry](http://github.com/cloudfoundry) components.

## OSS Contributions

The Cloud Foundry team uses GitHub and accepts contributions via [pull request](https://help.github.com/articles/using-pull-requests)

Follow these steps to make a contribution to any of our open source repositories:

1. Complete our CLA Agreement for [individuals](http://www.cloudfoundry.org/individualcontribution.pdf) or [corporations](http://www.cloudfoundry.org/corpcontribution.pdf)
1. Set your name and email

		git config --global user.name "Firstname Lastname"
		git config --global user.email "your_email@youremail.com"

Fork the BOSH repo

Make your changes on a topic branch, commit, and push to github and open a pull request.

Once your commits are approved by Travis CI and reviewed by the core team, they will be merged. 
