#!/usr/bin/env bash
set -eu -o pipefail

# install needed dependencies so that this task can be run on a stock ubuntu image
export DEBIAN_FRONTEND="noninteractive"
export LANG="en_US.UTF-8"
export LC_ALL="${LANG}"
export TZ="Etc/UTC"
apt-get update -y
apt-get install -y --no-install-recommends ca-certificates curl jq yq

# The image is built on the same architecture as this task runs on.
case "$(uname -m)" in
  x86_64)  arch="amd64" ;;
  aarch64) arch="arm64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

bosh_cli_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/cloudfoundry/bosh-cli/releases/latest \
                | jq -r --arg a "linux-${arch}" '.assets[] | select(.name | contains ($a)) | .browser_download_url')"
if [ "${arch}" = "amd64" ]; then
  credhub_cli_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/cloudfoundry/credhub-cli/releases/latest \
                     | jq -r '.assets[] | select(.name | match("credhub-linux-amd64-[0-9.]+\\.tgz$")) | .browser_download_url')"
  meta4_cli_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/dpb587/metalink/releases/latest \
                  | jq -r '.assets[] | select(.name | match("meta4-[0-9]+.[0-9]+.[0-9]+-linux-amd64")) | .browser_download_url')"
  credhub_cli_line="CREDHUB_CLI_URL: \"${credhub_cli_url}\""
  meta4_cli_line="META4_CLI_URL: \"${meta4_cli_url}\""
else
  # credhub-cli and dpb587/metalink publish no arm64 binaries; the Dockerfile
  # builds them from source at these release tags.
  credhub_cli_version="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/cloudfoundry/credhub-cli/releases/latest \
                         | jq -r '.tag_name')"
  meta4_version="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/dpb587/metalink/releases/latest \
                   | jq -r '.tag_name')"
  credhub_cli_line="CREDHUB_CLI_VERSION: \"${credhub_cli_version}\""
  meta4_cli_line="META4_VERSION: \"${meta4_version}\""
fi
yq_cli_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/mikefarah/yq/releases/latest \
                | jq -r --arg a "linux_${arch}" '.assets[] | select(.name | endswith ($a)) | .browser_download_url')"
ruby_install_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/postmodern/ruby-install/releases/latest \
                    | jq -r '.assets[] | select(.name | endswith ("tar.gz")) | .browser_download_url')"
golangci_lint_install_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/golangci/golangci-lint/releases/latest \
                    | jq -r --arg a "linux-${arch}" '.assets[] | select(.name | test("golangci-lint-[0-9]+.[0-9]+.[0-9]+-" + $a + ".tar.gz$")) | .browser_download_url')"

uaa_release_url="$(yq -r '.[] | select(.release == "uaa").value.url' < bosh-deployment/uaa.yml)"
java_install_prefix="/usr/lib/jvm"

gem_home="/usr/local/bundle"
ruby_version="$(cat bosh/src/.ruby-version)"

cat << YAML > docker-build-args/docker-build-args.yml
BOSH_CLI_URL: "${bosh_cli_url}"
${credhub_cli_line}
${meta4_cli_line}
GOLANGCI_LINT_INSTALL_URL: "${golangci_lint_install_url}"
YQ_CLI_URL: "${yq_cli_url}"
RUBY_INSTALL_URL: "${ruby_install_url}"
RUBY_VERSION: "${ruby_version}"
GEM_HOME: "${gem_home}"
UAA_RELEASE_URL: "${uaa_release_url}"
JAVA_INSTALL_PREFIX: "${java_install_prefix}"
POSTGRES_MAJOR_VERSION: "${POSTGRES_MAJOR_VERSION}"
YAML

if [ "${arch}" = "arm64" ]; then
  # The JDK in UAA's compiled release is x86_64; use the same vendor's aarch64
  # build of the same major version (BellSoft Liberica JDK 25, as in UAA 79.x).
  jdk_url="$(curl -s "https://api.bell-sw.com/v1/liberica/releases?version-feature=25&os=linux&arch=arm&bitness=64&package-type=tar.gz&bundle-type=jdk&version-modifier=latest" \
             | jq -r '.[0].downloadUrl')"
  echo "JDK_URL: \"${jdk_url}\"" >> docker-build-args/docker-build-args.yml
fi

cat docker-build-args/docker-build-args.yml
