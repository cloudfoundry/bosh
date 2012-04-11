# Cloud Foundry OSS Resources #

_Cloud Foundry Open Source Platform as a Service_

* [Learn][Learn]
* [Ask Questions][Ask Questions]
* [File a Bug][File a Bug]
* [OSS Contributions][OSS Contributions]


## Learn ##

There is a Cloud Foundry documentation set for open source developers, and one for CloudFoundry.com users:

* Open Source Developers: [https://github.com/cloudfoundry/oss-docs](https://github.com/cloudfoundry/oss-docs)
* CloudFoundry.com users: [http://docs.cloudfoundry.com](http://docs.cloudfoundry.com)

To make changes to our documentation, follow the [OSS Contribution][oss] steps and contribute to the oss-docs repository.

## Ask Questions ##

Questions about the Cloud Foundry Open Source Project can be directed to our Google Groups: [http://groups.google.com/a/cloudfoundry.org/groups/dir](http://groups.google.com/a/cloudfoundry.org/groups/dir)

Questions about CloudFoundry.com can be directed to: [http://support.cloudfoundry.com](http://support.cloudfoundry.com)

## File a Bug ##

To file a bug against Cloud Foundry Open Source and its components, sign up and use our bug tracking system: [http://cloudfoundry.atlassian.net](http://cloudfoundry.atlassian.net)

## OSS Contributions ##

The Cloud Foundry team uses Gerrit, a code review tool that originated in the Android Open Source Project. We also use GitHub as an official mirror, though all pull requests are accepted via Gerrit.

Follow these steps to make a contribution to any of our open source repositories:

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

Once your commits are approved you should see your revisions go from OPEN to MERGED and be replicated to GitHub. If you get feedback on your submission, we recommend squashing your commit with the original change-id. See the squashing section here for more details: [http://help.github.com/rebase/](http://help.github.com/rebase/).

Every Gerrit repository is mirrored at [http://github.com/cloudfoundry/](https://github.com/cloudfoundry/)