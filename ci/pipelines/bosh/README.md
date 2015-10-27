# Steps for Configuring the BOSH Pipeline

- [ ] 0. Set up environment
      ``` bash
      export BOSH_PATH=</PATH/TO/BOSH>
      export GIT_BRANCH=<BRANCH>
      export LASTPASS_USER=<USERNAME@pivotal.io>
      export LASTPASS_NOTE="BOSH concourse secrets"
      ```
- [ ] 1. Configure the pipeline
      ``` bash
      # Update BOSH
      cd $BOSH_PATH
      git co $GIT_BRANCH
      git pull

      # Get pipeline secrets (see "lpass" installation notes below)
      lpass login $LASTPASS_USER
      lpass show --notes "${LASTPASS_NOTE}" > /tmp/bosh-secrets.yml

      # Configure the pipeline
      fly -t production configure -c ci/pipelines/bosh/pipeline.yml \
        --var branch=$GIT_BRANCH \
        --vf /tmp/bosh-secrets.yml bosh
      ```

## Notes

- To install the LastPass CLI:
  ``` bash
  brew install lastpass-cli --with-pinentry
  ```
