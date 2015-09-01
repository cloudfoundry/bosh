# Steps for High-Priority, "Hotfix" Releases

## If there are no code changes

(only kernel and/or package updates)...

  1. Create a `hotfix-STORY_ID` branch off of `master`
  2. Push the hotfix branch
  3. Kick off OS Image build(s) with hotfix branch for `BUILD_FLOW_GIT_COMMIT`
  4. Update:
    - `bosh-stemcell/OS_IMAGES.md`
    - `bosh-dev/.../os_image_versions.json`

     with the published OS image s3 key, found at the end of the OS image build
     output; push that change
  1. Update the `promote_artifacts` step to reference `hotfix-STORY_ID`,
     instead of `develop`.

    **NOTE:** this build step will (automatically)...
    1. Merge the branch to master
    2. Bump BOSH gem versions (by way of applying a patch) and commit and
       push that on `master`, with "Adding final release..."
    3. Publish all the gems
    4. Merge the "Adding final release..." commit onto the hotfix branch
  6. Kick off the full Jenkins pipeline, based on the hotfix branch
  7. Locally, pull the hotfix branch changes and merge/push those to `develop`
  8. Update the `promote_artifacts` step to switch back to `develop`

## If there are code changes

(to bosh or bosh-agent)...

  1. Create a `hotfix-STORY_ID` branch off of `master`
  2. Make code changes and push the hotfix branch
  3. Copy `ci/pipeline.yml` to `ci/pipeline-hotfix-STORY_ID.yml` and
     configure a new `hotfix-STORY_ID` pipeline; push this change

    **NOTE:** this pipeline should...
    1. Reference the hotfix branch
    2. **Exclude** the `promote-candidate` and `publish-coverage` steps
  4. Follow steps 3-8 above (if there are no OS changes, you can probably
     skip steps 3 & 4 from above)

## Caveats:

- If your vars-from contents (secrets) are out of sync between `master` and
  `develop` at the start of all of this, well... hmm...
