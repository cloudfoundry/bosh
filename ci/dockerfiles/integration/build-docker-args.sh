#!/usr/bin/env bash
set -eu -o pipefail

# install needed dependencies so that this task can be run on a stock ubuntu image
apt-get update -y
apt-get install -y ca-certificates curl jq

bosh_cli_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/cloudfoundry/bosh-cli/releases/latest \
                | jq -r '.assets[] | select(.name | contains ("linux-amd64")) | .browser_download_url')"
meta4_cli_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/dpb587/metalink/releases/latest \
                | jq -r '.assets[] | select(.name | match("meta4-[0-9]+.[0-9]+.[0-9]+-linux-amd64")) | .browser_download_url')"
yq_cli_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/mikefarah/yq/releases/latest \
                | jq -r '.assets[] | select(.name | endswith ("linux_amd64")) | .browser_download_url')"
ruby_install_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/postmodern/ruby-install/releases/latest \
                    | jq -r '.assets[] | select(.name | endswith ("tar.gz")) | .browser_download_url')"
golangci_lint_install_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/golangci/golangci-lint/releases/latest \
                    | jq -r '.assets[] | select(.name | match("golangci-lint-[0-9]+.[0-9]+.[0-9]+-linux-amd64.tar.gz")) | .browser_download_url')"

uaa_release_url="$(bosh int bosh-deployment/uaa.yml --path /release=uaa/value/url)"
java_install_prefix="/usr/lib/jvm"

gem_home="/usr/local/bundle"
ruby_version="$(cat bosh/src/.ruby-version)"

postgres_major_version="13"

cat << JSON > docker-build-args/docker-build-args.json
{
  "BOSH_CLI_URL": "${bosh_cli_url}",
  "META4_CLI_URL": "${meta4_cli_url}",
  "GOLANGCI_LINT_INSTALL_URL":"${golangci_lint_install_url}",
  "YQ_CLI_URL": "${yq_cli_url}",

  "RUBY_INSTALL_URL": "${ruby_install_url}",
  "RUBY_VERSION": "${ruby_version}",
  "GEM_HOME": "${gem_home}",

  "UAA_RELEASE_URL": "${uaa_release_url}",
  "JAVA_INSTALL_PREFIX": "${java_install_prefix}",

  "POSTGRES_MAJOR_VERSION": "${postgres_major_version}"
}
JSON

cat docker-build-args/docker-build-args.json
