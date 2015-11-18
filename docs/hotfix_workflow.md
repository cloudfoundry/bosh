# Steps for High-Priority, "Hotfix" Releases

## Important!!!:

- Upon completion of the steps below, **do not** kick off another Jenkins pipeline build (off of the `candidate` branch)
  until the changes from the steps below have made it through the Concourse pipeline.

## For OS image builds...

- [ ] 0. Set up environment
      ``` bash
      export BOSH_PATH=</PATH/TO/BOSH>
      export LASTPASS_USER=<USERNAME@pivotal.io>
      export HOTFIX_NAME="hotfix-<TRACKER STORY ID>"
      export HOTFIX_IMG_PIPELINE="bosh:os-image:$HOTFIX_NAME"
      export HOTFIX_BOSH_PIPELINE="bosh:$HOTFIX_NAME"
      ```
- [ ] 1. Create a hotfix branch off of `master`
      ``` bash
      cd $BOSH_PATH
      git co master
      git pull
      git co -b $HOTFIX_NAME
      git push -u origin $HOTFIX_NAME
      ```
- [ ] 2. Produce OS images (from the hotfix branch)
  - [ ] A. Create a Concourse hotfix pipeline for OS Image building
        ``` bash
        cd $BOSH_PATH
        cp ci/pipelines/os-image/pipeline.yml /tmp/hotfix-image-pipeline.yml

        # Get pipeline secrets (see "lpass" installation notes below)
        lpass login $LASTPASS_USER
        lpass show --notes "OS image concourse secrets" > /tmp/hotfix-image-secrets.yml

        # Configure the pipeline
        fly -t production configure -c /tmp/hotfix-image-pipeline.yml \
          --var branch=$HOTFIX_NAME \
          --vf /tmp/hotfix-image-secrets.yml $HOTFIX_IMG_PIPELINE
        ```
  - [ ] B. Make any image-building changes and push those to the hotfix branch
  - [ ] C. Run the pipeline
        ``` bash
        # 1. Open in your browser
        open https://main.bosh-ci.cf-app.com/pipelines/$HOTFIX_IMG_PIPELINE
        # 2. Un-pause the pipeline
        # 3. Trigger the "start-job" job
        ```
- [ ] 3. Produce BOSH changes (from the hotfix branch)
  - [ ] A. Update BOSH with OS image details
      - Retrieve the OS image S3 keys from the end of the OS image build output
      - Update the following files:
        - `bosh-stemcell/OS_IMAGES.md`
        - `bosh-dev/lib/bosh/dev/config/os_image_versions.json`
      - Commit and push those changes to the hotfix branch
         ``` bash
         git add bosh-stemcell/OS_IMAGES.md bosh-dev/lib/bosh/dev/config/os_image_versions.json
         git ci # Edit commit message appropriately, including the Tracker story ID
         pit push origin $HOTFIX_NAME
         ```
  - [ ] B. **If there are BOSH code changes** (other than OS image building changes)
    - [ ] 1. Create a Concourse hotfix pipeline for BOSH
          ``` bash
          cd $BOSH_PATH
          cp ci/pipeline.yml /tmp/hotfix-bosh-pipeline.yml

          # Configure...
          # TODO:
          # - How to get the secrets and put them in /tmp/hotfix-bosh-secrets.yml
          # - How to update the bosh-src resource via vars or editing the
          #   pipeline file to point to the $HOTFIX_NAME branch
          # - Remove the "promote-candidate" and "publish-coverage"

          # Configure the pipeline
          fly -t production configure -c /tmp/hotfix-bosh-pipeline.yml \
            --var branch=$HOTFIX_NAME \
            --vf /tmp/hotfix-bosh-secrets.yml $HOTFIX_BOSH_PIPELINE
          ```
    - [ ] 2. Make code changes and push those to the hotfix branch
    - [ ] 3. Run the pipeline
          ``` bash
          # 1. Open in your browser
          open https://main.bosh-ci.cf-app.com/pipelines/$HOTFIX_BOSH_PIPELINE
          # 2. Un-pause the pipeline
          # 3. Trigger the "start-job" job
          ```
- [ ] 4. Run the Jenkins pipeline based on the hotfix branch, setting `BUILD_FLOW_GIT_COMMIT` **and** `FEATURE_BRANCH` as $HOTFIX_NAME.
      NOTE: The final step of the Jenkins pipeline will commit a release bump to `master` and merge that to the hotfix branch.
- [ ] 5. Upon successful completion of the Jenkins pipeline, merge the changes into develop
      ``` bash
      git co master && git pull
      git co develop && git pull
      git merge master # Resolve merge any conflicts
      git push origin develop
      ```
- [ ] 6. Clean up
      ``` bash
      # Tear down the Concourse hotfix pipelines
      fly -t production destroy-pipeline $HOTFIX_IMG_PIPELINE
      fly -t production destroy-pipeline $HOTFIX_BOSH_PIPELINE
      ```

## Notes

- It is not recommended that non-hotfix OS images builds run concurrently with hotfix builds. While there is no technical limitation, the contextual overhead is higher. When kicking of a hotfix build, cancel any other running OS image builds.
- To install the LastPass CLI:
  ``` bash
  brew install lastpass-cli --with-pinentry
  ```
- To download the OS image (for debugging/acceptance):
  ``` bash
  IMAGE_FILE="..."  # From the end of the build output.
                    # e.g, bosh-ubuntu-trusty-os-image.tgz
  VERSION_ID="..."  # From the end of the build output.
                    # A 32 character alpha-numeric string
  wget "http://s3.amazonaws.com/bosh-os-images/${IMAGE_FILE}?versionId=${VERSION_ID}" \
    -O "${IMAGE_FILE}"
  ```
