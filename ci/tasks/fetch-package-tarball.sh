#!/usr/bin/env bash
set -euo pipefail

mkdir -p package-src
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

write_status() {
  printf '%s\n%s\n' "$1" "$2" > package-src/status
}

fail() {
  write_status fail "$1"
  exit 1
}

skip() {
  write_status skip "$1"
  exit 1
}

request() {
  local url=$1 output=$2 code
  if ! code=$(curl --location --max-redirs 5 --silent --show-error --connect-timeout 15 --max-time 300 --output "$output" --write-out '%{http_code}' "$url"); then
    return 1
  fi
  printf '%s' "$code"
}

case "${PACKAGE:-}" in
  postgres)
    if [[ ! $(cat package-tag/.git/tag) =~ ^REL_([0-9]+)_([0-9]+)$ ]]; then
      fail "Unsupported postgres tag: $(cat package-tag/.git/tag)"
    fi
    version="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
    resource="postgres-${BASH_REMATCH[1]}-src"
    filename="postgresql-${version}.tar.gz"
    url="https://ftp.postgresql.org/pub/source/v${version}/${filename}"
    ;;
  mariadb)
    if [[ ! $(cat package-tag/.git/tag) =~ ^v(3\.[0-9]+\.[0-9]+)$ ]]; then
      fail "Unsupported mariadb tag: $(cat package-tag/.git/tag)"
    fi
    version="${BASH_REMATCH[1]}"
    filename="mariadb-connector-c-${version}-src.tar.gz"
    url="https://archive.mariadb.org/connector-c-${version}/${filename}"
    ;;
  *) fail "Unsupported PACKAGE: ${PACKAGE:-}" ;;
esac

if [[ $PACKAGE == mariadb ]]; then
  index_url=https://mariadb.org/connector-c/all-releases/
  if ! code=$(request "$index_url" "$tmpdir/index"); then
    fail "Could not fetch mariadb release index: $index_url"
  fi
  [[ $code == 200 ]] || fail "Mariadb release index returned HTTP $code: $index_url"
  index=$(tr '\r\n\t' '   ' < "$tmpdir/index" | sed -E 's/[[:space:]]+/ /g; s#</tr>#</tr>\n#g')
  recognized=0
  matches=0
  release_status=
  while IFS= read -r row; do
    if [[ $row =~ \>[[:space:]]?(3\.[0-9]+\.[0-9]+)[[:space:]]?\</a\>[[:space:]]?\</td\>[[:space:]]?\<td\>([0-9-]+)\</td\>[[:space:]]?\<td\>([A-Za-z]+) ]]; then
      recognized=$((recognized + 1))
      if [[ ${BASH_REMATCH[1]} == "$version" ]]; then
        matches=$((matches + 1))
        release_status=${BASH_REMATCH[3]}
      fi
    fi
  done <<< "$index"
  (( recognized > 0 )) || fail "Could not recognize mariadb release index rows: $index_url"
  (( matches <= 1 )) || fail "Multiple mariadb index rows found for v${version}: $index_url"
  [[ $matches == 1 && $release_status == Stable ]] || skip "Tag v${version} is not listed Stable on $index_url"
fi

if ! code=$(request "$url" "$tmpdir/${filename}.part"); then
  fail "Could not fetch tarball: $url"
fi
if [[ $code == 404 ]]; then
  if [[ $PACKAGE == mariadb ]]; then
    fail "Stable mariadb tarball returned HTTP 404: $url"
  fi
  commit_date=$(cat package-tag/.git/commit_timestamp)
  if [[ -z $commit_date ]] || ! commit=$(date -u -d "$commit_date" +%s 2>/dev/null); then
    fail "Invalid committer_date for tag $(cat package-tag/.git/tag): $commit_date"
  fi
  deadline=$((commit + 7 * 86400))
  deadline_utc=$(date -u -d "@$deadline" '+%Y-%m-%d %H:%M:%S UTC')
  details="Tag $(cat package-tag/.git/tag); missing tarball $url; commit date $commit_date; deadline $deadline_utc"
  if (( $(date -u +%s) < deadline )); then
    skip "$details"
  fi
  fail "$details; disable with: fly -t bosh disable-resource-version -r bosh-director/${resource} -v tag:$(cat package-tag/.git/tag)"
fi
[[ $code == 200 ]] || fail "Tarball request returned HTTP $code: $url"

if [[ $PACKAGE == postgres ]]; then
  checksum_url="${url}.sha256"
else
  checksum_url="https://archive.mariadb.org/connector-c-${version}/sha256sums.txt"
fi
if ! code=$(request "$checksum_url" "$tmpdir/checksums"); then
  fail "Could not fetch checksum: $checksum_url"
fi
[[ $code == 200 ]] || fail "Checksum request returned HTTP $code: $checksum_url"
if [[ $PACKAGE == postgres ]]; then expected=$filename; else expected="./${filename}"; fi
mapfile -t sums < <(tr -d '\r' < "$tmpdir/checksums" | awk -v file="$expected" '$2 == file {print $1}')
(( ${#sums[@]} == 1 )) || fail "Expected exactly one checksum for $expected at $checksum_url"
[[ ${sums[0]} =~ ^[0-9a-f]{64}$ ]] || fail "Invalid SHA-256 checksum for $expected at $checksum_url"
actual=$(sha256sum "$tmpdir/${filename}.part" | awk '{print $1}')
[[ $actual == "${sums[0]}" ]] || fail "SHA-256 mismatch for $filename"
mv "$tmpdir/${filename}.part" "package-src/$filename"
write_status ready "Fetched and verified $filename for tag $(cat package-tag/.git/tag)"
