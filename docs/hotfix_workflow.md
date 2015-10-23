# Steps for High-Priority, "Hotfix" Releases

## Important!!!:

- Do not kick off another Jenkins pipeline build (off of the `candidate` branch)
  until the changes from the steps below have made it through the Concourse pipeline.

## If there are no code changes

(only kernel and/or package updates)...

- [ ] 1. Create a `hotfix-STORY_ID` branch off of `master`
- [ ] 2. Push the hotfix branch: `git push -u origin hotfix-STORY_ID`
- [ ] 3. Kick off appropriate OS Image build(s) with `hotfix-STORY_ID` as the value for `BUILD_FLOW_GIT_COMMIT`
- [ ] 4. Update (on the hotfix branch):
  - `bosh-stemcell/OS_IMAGES.md`
  - `bosh-dev/.../os_image_versions.json`

  ...with the published OS image s3 key, found at the end of the OS image build output; push that change
- [ ] 5. Kick off the full Jenkins pipeline, based on the hotfix branch, setting `BUILD_FLOW_GIT_COMMIT` **and** `FEATURE_BRANCH` as `hotfix-STORY_ID`
         NOTE: The final step of the Jenkins pipeline will commit a release bump to `master` and merge that to `hotfix-STORY_ID`
- [ ] 6. Upon successful completion of the Jenkins pipeline, locally...
  - [ ] `git co master && git pull`
  - [ ] `git co develop && git pull`
  - [ ] `git merge master` (onto `develop`) # Resolve any merge conflicts
  - [ ] `git commit` # Accept the standard commit message
  - [ ] `git push origin develop`
  - [ ] optionally, delete the local and remote hotfix branches:
      `git branch -d hotfix-STORY_ID`
      `git push origin :hotfix-STORY_ID`

## If there are code changes

(to bosh or bosh-agent)...

- [ ] 1. Create a `hotfix-STORY_ID` branch off of `master`
- [ ] 2. Make code changes and push the hotfix branch
- [ ] 3. Copy `ci/pipeline.yml` to `ci/pipeline-hotfix-STORY_ID.yml` and configure a new `hotfix-STORY_ID` pipeline; push this change

    **NOTE:** this pipeline should...
  - [ ] Reference the hotfix branch
  - [ ] **Exclude** the `promote-candidate` and `publish-coverage` steps
- [ ] 4. Follow steps 3-5 above (if there are no OS changes, you can probably skip steps 3 & 4)
- [ ] 5. Follow step 6 above, but `git rm ci/pipeline-hotfix-STORY_ID.yml` before pushing `develop`

## Edge-case: If second image was built consecutively off of `develop`

Once the hotfix build has made it through the pipeline and is therefore merged to `develop`, build a third image off of `develop`, wait for the relevant changes (to `OS_IMAGES.md` and `os_image_versions.json`) to go through Concourse, and finally kick off another Jenkins build.

## Debugging/Acceptance

To download the OS image:

``` bash
IMAGE_FILE="..."  # From the end of the build output.
                  # e.g, bosh-ubuntu-trusty-os-image.tgz
VERSION_ID="..."  # From the end of the build output.
                  # A 32 character alpha-numeric string
wget "http://s3.amazonaws.com/bosh-os-images/${IMAGE_FILE}?versionId=${VERSION_ID}" \
  -O "${IMAGE_FILE}"
```
