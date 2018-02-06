set -exu -o pipefail

ROOT="$(pwd)"

SLACK_ATTACHMENT_TEMPLATE='{
    "color": "#ff0000",
    "title": $title,
    "mrkdwn_in": ["fields"],
    "fields": [
        {"title": "Author", "short": true, "value": $author},
        {"title": "Committer", "short": true, "value": $committer}
    ]
}'

function main() {
  local attachments="[]"
  for repo in ${ROOT}/bosh-src; do
    local attachment="$(jq -n \
      --arg title "$(basename "${repo}") $(get_commit_link "${repo}") - $(get_commit_message "${repo}") ($(get_commit_date "${repo}"))" \
      --arg author "$(get_author_name "${repo}")" \
      --arg committer "$(get_committer_name "${repo}")" \
      "${SLACK_ATTACHMENT_TEMPLATE}")"

    attachments="$(echo "${attachments}" | jq \
        --argjson attachment "${attachment}" \
        '. += [$attachment]')"
  done

  echo "${attachments}" \
    > "${ROOT}/slack-notification/attachments"
}

function get_repo_ref() {
  local repo="${1}"
  git -C "${repo}" show -s --format=%h "$(cat "${repo}/.git/ref")"
}

function get_commit_link() {
  local repo="${1}"
  local ref="$(get_repo_ref ${repo})"
  echo "<https://$(git -C "${repo}" remote get-url origin | cut -d@ -f2 | sed -e 's|:|/|' -e 's|.git$||')/commit/${ref}|${ref}>"
}

function get_commit_date() {
  local repo="${1}"
  git -C "${repo}" show -s --format="%cr" "$(get_repo_ref "${repo}")"
}

function get_commit_message() {
  local repo="${1}"
  git -C "${repo}" show -s --format="%s" "$(get_repo_ref "${repo}")"
}

function get_author_name() {
  local repo="${1}"
  local author=$(git -C "${repo}" show -s --format="%ae" "$(get_repo_ref "${repo}")")

  get_slacker_name "${author}"
}

function get_committer_name() {
  local repo="${1}"
  local committer=$(git -C "${repo}" show -s --format="%ce" "$(get_repo_ref "${repo}")")

  get_slacker_name "${committer}"
}

function get_slacker_name() {
  echo "<@here>"
}

main
