# Instructions for Manual Release of BOSH

Sometimes we want to create a release outside of Jenkins for a hotfix. Only do this when you know you're supposed to and when pairing with Dmitriy.

This doc is an example from when bumping from 256.9 to 256.10.


## Prerequisites

Work from a checkout of `bosh`...

	$ cd ~/workspace/bosh

Configure `private.yml` so you can upload artifacts later...

	$ vim release/config/private.yml

Use a recent version of the `bosh` CLI...

	$ gem update bosh_cli

Update your duet names...

	$ git duet db dk


## Release Steps

Checkout the maintenance branch...

	$ git checkout 256.x
	$ git reset --hard
	$ git pull --ff-only
	$ git submodule update

Double check you're working from the commit you expect...

	$ git show

Lookup which version is the next version...

	$ open https://github.com/cloudfoundry/bosh/releases
	# remember that our tagging methods can be confusing

Create your dev release with that version...

	$ export CANDIDATE_BUILD_NUMBER=3232.10
	$ export CANDIDATE_RELEASE_NUMBER=256.10
	$ bundle exec rake release:create_dev_release

Create a tarball from the release YAML file which was created and output at the end...

	$ cd release/
	$ bosh create release dev_releases/bosh/bosh-256.9+dev.1.yml

Reset changes again to switch back to master...

	$ git reset --hard
	$ git checkout master

Pull the latest changes...

	$ git pull --ff-only
	$ git submodule update

Finalize the release...

	$ bosh finalize release --version $CANDIDATE_RELEASE_NUMBER dev_releases/bosh/bosh-256.9+dev.1.tgz

Verify the diff looks sane

	$ git diff

Compare the old and new release manifests. You should see only the few packages which were changed. Also take a look at the `commit_hash` to ensure it's the commit you expect...

	$ diff -C 5 releases/bosh-256.{9,10}.yml

Commit the release...

	$ git add .final_builds releases/bosh-$CANDIDATE_RELEASE_NUMBER.yml releases/index.yml
	$ git ci -m "Adding final release for build $CANDIDATE_BUILD_NUMBER (v$CANDIDATE_RELEASE_NUMBER) finalized on master"

Tag the release...

	$ git tag stable-$CANDIDATE_BUILD_NUMBER

Switch to the maintenance branch and cherry-pick the release commit. You may have to manually resolve the blob files (should only be adding extra new lines, never deleting)...

	$ git co 256.x
	$ git cherry-pick master
	$ git add .final_builds releases/bosh-$CANDIDATE_RELEASE_NUMBER.yml releases/index.yml
	$ git ci -m "Adding final release for build $CANDIDATE_BUILD_NUMBER (v$CANDIDATE_RELEASE_NUMBER) finalized on master"

STOP. You just manually created a release that the world is going to use. Rethink and double check everything you did/didn't do before continuing :)

Publish...

	$ git push origin master 256.x stable-$CANDIDATE_BUILD_NUMBER

Create the release notes on GitHub...

	$ open https://github.com/cloudfoundry/bosh/releases/edit/stable-$CANDIDATE_BUILD_NUMBER


## Notes

 * we may want to consider not cherry-picking back to the maintenance branch. master is authoritative anyway, so, why bother. It also means we have release references in `releases/index.yml` which don't actually exist on the filesystem which is logically confusing.
