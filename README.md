# BOSH

Cloud Foundry BOSH is an open source tool chain for release engineering, deployment and lifecycle management of large scale distributed services. In this manual we describe the architecture, topology, configuration, and use of BOSH, as well as the structure and conventions used in packaging and deployment.

* BOSH Documentation: [https://github.com/cloudfoundry/oss-docs/blob/master/bosh/documentation/documentation.md](https://github.com/cloudfoundry/oss-docs/blob/master/bosh/documentation/documentation.md)

# Cloud Foundry OSS Resources #

_Cloud Foundry Open Source Platform as a Service_

## Learn ##

There is a Cloud Foundry documentation set for open source developers, and one for CloudFoundry.com users:

* Open Source Developers: [https://github.com/cloudfoundry/oss-docs](https://github.com/cloudfoundry/oss-docs)
* CloudFoundry.com users: [http://docs.cloudfoundry.com](http://docs.cloudfoundry.com)

To make changes to our documentation, follow the [OSS Contribution][oss] steps and contribute to the oss-docs repository.

## Ask Questions

Questions about the Cloud Foundry Open Source Project can be directed to our Google Groups.

BOSH Developers: [https://groups.google.com/a/cloudfoundry.org/group/bosh-dev/topics](https://groups.google.com/a/cloudfoundry.org/group/bosh-dev/topics)
BOSH Users:[https://groups.google.com/a/cloudfoundry.org/group/bosh-users/topics](https://groups.google.com/a/cloudfoundry.org/group/bosh-users/topics)
VCAP (Cloud Foundry) Developers: [https://groups.google.com/a/cloudfoundry.org/group/vcap-dev/topics](https://groups.google.com/a/cloudfoundry.org/group/vcap-dev/topics)

Questions about CloudFoundry.com can be directed to: [http://support.cloudfoundry.com](http://support.cloudfoundry.com)

## File a Bug

To file a bug against Cloud Foundry Open Source and its components, sign up and use our bug tracking system: [http://cloudfoundry.atlassian.net](http://cloudfoundry.atlassian.net)

## OSS Contributions

The Cloud Foundry team uses Gerrit, a code review tool that originated in the Android Open Source Project. We also use GitHub as an official mirror, though all pull requests are accepted via Gerrit.

Follow these steps to make a contribution to any of our open source repositories:

1. Complete our CLA Agreement for [individuials](http://www.cloudfoundry.org/individualcontribution.pdf) or [corporations](http://www.cloudfoundry.org/corpcontribution.pdf)
1. Sign up for an account on our public Gerrit server at http://reviews.cloudfoundry.org/
1. Create and upload your public SSH key in your Gerrit account profile
1. Set your name and email

		git config --global user.name "Firstname Lastname"
		git config --global user.email "your_email@youremail.com"

Install our gerrit-cli gem:

		gem install gerrit-cli

Clone the Cloud Foundry repo

_Note: to clone the BOSH repo, or the Documentation repo, replace `vcap` with `bosh` or `oss-docs`_

		gerrit clone ssh://reviews.cloudfoundry.org:29418/vcap
		cd vcap

Make your changes, commit, and push to gerrit:

		git commit
		gerrit push

Once your commits are approved by our Continuous Integration Bot (CI Bot) as well as our engineering staff, return to the Gerrit interface and MERGE your changes. The merge will be replicated to GitHub automatically at [http://github.com/cloudfoundry/](https://github.com/cloudfoundry/). If you get feedback on your submission, we recommend squashing your commit with the original change-id. See the squashing section here for more details: [http://help.github.com/rebase/](http://help.github.com/rebase/).

After the CI Bot successfully tests your change, you need to ask some Reviewers to accept your commit.

Add a reviewer "Platforms Team", which explodes out into a subset of VMWare employees who work on BOSH. You can also add explicit reviewers by their name.

Once your commit has been given a "+2" by one of the reviewers above, you can then merge your commit in via Gerrit dashboard.

Finally, your contribution will be available via the gerrit and github git repositories.
