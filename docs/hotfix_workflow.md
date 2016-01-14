# Steps for High-Priority, "Hotfix" Releases

## Important!!!:

- Upon completion of the steps below, **do not** kick off another Jenkins pipeline build (of the `candidate` branch)
  until the changes from the steps below have made it through the Concourse pipeline.

## For OS image builds...

- [ ] 0. Set up environment

      ```bash
      export BOSH_PATH=</PATH/TO/BOSH>
      export LASTPASS_USER=<USERNAME@pivotal.io>
      export HOTFIX_NAME="hotfix-<TRACKER STORY ID>"
      export HOTFIX_IMG_PIPELINE="bosh:os-image:$HOTFIX_NAME"
      export HOTFIX_BOSH_PIPELINE="bosh:$HOTFIX_NAME"

      # Log in to LastPass (for pipeline configuration)
      lpass login $LASTPASS_USER
      ```
- [ ] 1. Create a hotfix branch from the `master` branch

      ```bash
      cd $BOSH_PATH
      git co master
      git pull --ff-only
      git co -b $HOTFIX_NAME
      git push -u origin $HOTFIX_NAME
      ```
- [ ] 2. Produce OS images (from the hotfix branch)
  - [ ] A. Create a Concourse hotfix pipeline for OS Image building

        ```bash
        cd $BOSH_PATH
        cp ci/pipelines/os-image/pipeline.yml /tmp/hotfix-image-pipeline.yml

        # Configure the pipeline
        fly -t production set-pipeline -c /tmp/hotfix-image-pipeline.yml \
          --var branch=$HOTFIX_NAME \
          --load-vars-from <( lpass show --notes "OS image concourse secrets" ) -p $HOTFIX_IMG_PIPELINE
        ```
  - [ ] B. Make any image-building changes and push those to the hotfix branch
  - [ ] C. Run the pipeline

        ```bash
        # 1. unpause the pipeline
        fly -t production unpause-pipeline -p $HOTFIX_IMG_PIPELINE
        # 2. point your browser to the pipeline
        open https://main.bosh-ci.cf-app.com/pipelines/$HOTFIX_IMG_PIPELINE
        # 3. trigger the "start-job" job
        ```
- [ ] 3. Produce BOSH changes (from the hotfix branch)
  - [ ] A. Update BOSH with OS image details
      - Retrieve the OS image S3 keys from the end of the OS image build output
      - Update the following files:
        - `bosh-stemcell/OS_IMAGES.md`
        - `bosh-stemcell/os_image_versions.json`
      - Commit and push those changes to the hotfix branch

         ```bash
         git add bosh-stemcell
         git ci # Edit commit message appropriately, including the Tracker story ID
         git push origin $HOTFIX_NAME
         ```
  - [ ] B. **If there are BOSH code changes** (other than OS image building changes)
    - [ ] 1. Create a Concourse hotfix pipeline for BOSH

          ```bash
          cd $BOSH_PATH
          cp ci/pipeline.yml /tmp/hotfix-bosh-pipeline.yml

          # Configure the pipeline
          fly -t production set-pipeline -c /tmp/hotfix-bosh-pipeline.yml \
            --var branch=$HOTFIX_NAME \
            --load-vars-from <( lpass show --notes "bosh concourse secrets" ) -p $HOTFIX_BOSH_PIPELINE
          ```
    - [ ] 2. Make code changes and push those to the hotfix branch
    - [ ] 3. Run the pipeline

          ```bash
          # 1. Open in your browser
          open https://main.bosh-ci.cf-app.com/pipelines/$HOTFIX_BOSH_PIPELINE
          # 2. Un-pause the pipeline
          # 3. Trigger the "start-job" job
          ```
- [ ] 4. Run the [Jenkins pipeline](http://bosh-jenkins.cf-app.com:8080/job/bosh_build_flow/) based on the hotfix branch. Click **Rebuild Last** and set `BUILD_FLOW_GIT_COMMIT` **and** `FEATURE_BRANCH` as $HOTFIX_NAME.
      NOTE: The final step of the Jenkins pipeline will commit a release bump to `master` and merge that to the hotfix branch.
- [ ] 5. Upon successful completion of the Jenkins pipeline, merge the changes into develop

      ```bash
      git co master && git pull
      git co develop && git pull
      git merge master # Resolve merge any conflicts
      git push origin develop
      ```
- [ ] 6. Clean up

      ```bash
      # Tear down the Concourse hotfix pipelines
      fly -t production destroy-pipeline -p $HOTFIX_IMG_PIPELINE
      fly -t production destroy-pipeline -p $HOTFIX_BOSH_PIPELINE
      # Remove the now-merged branch
      git push origin :$HOTFIX_NAME
      ```

## Notes

- It is not recommended that non-hotfix OS images builds run concurrently with hotfix builds. While there is no technical limitation, the contextual overhead is higher. When kicking of a hotfix build, cancel any other running OS image builds.
- To install the LastPass CLI:

  ```bash
  brew install lastpass-cli --with-pinentry
  ```
- To download the OS image (for debugging/acceptance):

  ```bash
  IMAGE_FILE="..."  # From the end of the build output.
                    # e.g, bosh-ubuntu-trusty-os-image.tgz
  VERSION_ID="..."  # From the end of the build output.
                    # A 32 character alpha-numeric string
  wget "http://s3.amazonaws.com/bosh-os-images/${IMAGE_FILE}?versionId=${VERSION_ID}" \
    -O "${IMAGE_FILE}"
  ```
