#!/bin/bash
set -eu -o pipefail

cat <<EOF > settings.json
{
  "params": {
    "files": [ "compiled-release/*.tgz" ],
    "version": "candidate-version/version",
    "rename_from_file": "metalink-path/file-path",
    "options": {
      "message": "Update metalink from ${BUILD_TEAM_NAME}/${BUILD_PIPELINE_NAME}/${BUILD_JOB_NAME}/${BUILD_NAME}
    }
  },
  "source": {
    "uri": "git+ssh://git@github.com:cloudfoundry/bosh-compiled-releases-index.git",
    "mirror_files": [
      {
        "destination": "s3://s3-external-1.amazonaws.com/bosh-compiled-releases/bosh/{{.Version}}/{{.Name}}",
        "env": {
          "AWS_ACCESS_KEY_ID": "$AWS_ACCESS_KEY_ID",
          "AWS_SECRET_ACCESS_KEY": "$AWS_SECRET_ACCESS_KEY"
        }
      }
    ],
    "options": {
      "private_key": "$(echo "$git_private_key" | tr '\n' '#'|  sed 's/#/\\n/g')"
    }
  }
}
EOF

cat settings.json | /opt/resource/out $PWD
