# Steps for Configuring the BOSH Pipelines

- [ ] 0. Set up environment

      ```bash
      export PROJECT_NAME=<PROJECT_NAME>
      export PROJECT_PATH=</PATH/TO/PROJECT>
      export GIT_BRANCH=<BRANCH>
      export LASTPASS_USER=<USER NAME>
      export LASTPASS_NOTE="${PROJECT_NAME} concourse secrets"
      ```

- [ ] 1. Configure the pipeline

      ```bash
      cd $PROJECT_PATH
      git co $GIT_BRANCH
      git pull

      lpass login $LASTPASS_USER

      # NOTE: if not configuring "bosh", remove the branch var...
      fly -t production set-pipeline -c ci/pipeline.yml \
        --var branch=$GIT_BRANCH \
        --load-vars-from <(lpass show --notes "${LASTPASS_NOTE}") -p $PROJECT_NAME

      lpass logout
      ```

## Notes

- To install the LastPass CLI:

  ```bash
  brew install lastpass-cli --with-pinentry
  ```
