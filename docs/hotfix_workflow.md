# Steps for High-Priority, "Hotfix" Releases

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

## Important!!!:

- Do not kick off another Jenkins pipeline build (off of the `candidate` branch)
  until all changes from above have made it through the Concourse pipeline.
