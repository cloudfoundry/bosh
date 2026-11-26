#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
default_dependency=/var/vcap/packages/golang-1-linux
if [[ -e "$default_dependency" || -L "$default_dependency" ]]; then
  echo 'Run this test in a disposable container without installed BOSH packages.' >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -f "$default_dependency"; rm -rf "$work"' EXIT
mkdir -p "$work/dependency/bosh" "$work/dependency/bin" "$work/tools" \
  "$work/override" "$work/bosh-monitor/cmd/plugins/hm-fixture"
for tool in mkdir basename; do
  ln -s "$(command -v "$tool")" "$work/tools/$tool"
done
cat > "$work/dependency/bin/go" <<'GO'
#!/bin/bash
set -eu
case "$1" in
  version) printf 'go fixture toolchain\n' ;;
  build)
    test "$GOFLAGS" = '-mod=vendor'
    test "$GOPROXY" = off
    printf 'built using the declared dependency\n' > "$3"
    ;;
  *) exit 1 ;;
esac
GO
chmod +x "$work/dependency/bin/go"
printf 'export PATH=%q/bin:$PATH\n' "$work/dependency" > "$work/dependency/bosh/compile.env"
mkdir -p /var/vcap/packages
ln -s "$work/dependency" "$default_dependency"
ln -s "$work/dependency" "$work/override/golang-1-linux"

failures=0
for scenario in unset empty override missing; do
  output="$work/output-$scenario"
  if (
    cd "$work"
    export PATH="$work/tools" BOSH_INSTALL_TARGET="$output"
    unset BOSH_PACKAGES_DIR
    case "$scenario" in
      empty) export BOSH_PACKAGES_DIR='' ;;
      override) export BOSH_PACKAGES_DIR="$work/override" ;;
      missing) export BOSH_PACKAGES_DIR="$work/missing" ;;
    esac
    if command -v go; then exit 1; fi
    /bin/bash "$repo_root/packages/health_monitor/packaging"
  ) > "$work/$scenario.log" 2>&1; then
    if [[ "$scenario" == missing || ! -s "$output/bin/bosh-monitor" || ! -s "$output/bin/hm-fixture" ]]; then
      echo "FAIL: $scenario package directory"
      failures=$((failures + 1))
    else
      echo "PASS: $scenario package directory exposes the dependency toolchain"
    fi
  elif [[ "$scenario" == missing ]] && grep -q 'ERROR: Go toolchain not found.' "$work/$scenario.log"; then
    echo 'PASS: missing dependency fails without a host Go fallback'
  else
    echo "FAIL: $scenario package directory"
    cat "$work/$scenario.log"
    failures=$((failures + 1))
  fi
done
test "$failures" -eq 0
