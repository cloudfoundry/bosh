# Postgres Release Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the homegrown `postgres` and `postgres-13` BOSH jobs/packages in this repo with `cloudfoundry/postgres-release`, add matrix validation tests for PG versions 15/16/17/18, and deprecate `postgres-13`.

**Architecture:** Delete all in-repo postgres jobs, packages, blob-bumping CI tasks, and Docker image builds. Update BRATS manifests to co-locate the postgres-release job. Add a parameterized Go test file with a Ginkgo `DescribeTable` matrix and four parallel Concourse jobs. Deprecate `postgres-13` with a spec warning + pre-start log message.

**Tech Stack:** BOSH release (Ruby ERB templates, YAML specs), Go + Ginkgo v2 (BRATS tests), Concourse (CI pipeline YAML), Ruby (integration support helpers)

**Spec:** `docs/superpowers/specs/2026-07-02-postgres-release-migration-design.md`

---

## File Map

**Deleted:**
- `jobs/postgres/` (all contents)
- `packages/postgres-15/` (all contents)
- `packages/postgres-13/` (all contents)
- `spec/postgres_bpm_spec.rb`
- `ci/tasks/bump-postgres-packages.yml`
- `ci/tasks/bump-postgres-packages.sh`
- `ci/dockerfiles/main-postgres/Dockerfile`

**Modified:**
- `jobs/postgres-13/spec` — add deprecation warning to `description`
- `jobs/postgres-13/templates/pre-start.erb` — add deprecation log at top
- `config/blobs.yml` — remove postgres-13 and postgres-15 blob entries
- `src/brats/assets/postgres-manifest.yml` — switch to postgres-release job + `databases.*` properties
- `src/brats/assets/postgres-13-manifest.yml` — same, pin `databases.version: 13`
- `src/spec/integration_support/postgres_version_helper.rb` — read from `PG_VERSION` env var instead of parsing bosh job spec
- `ci/pipeline.yml` — remove old postgres jobs/images/resources; add `unit-director-postgres-17`, `build-main-postgres-17`, `integration-postgres-17-image` resource, and four `brats-postgres-*` jobs

**Created:**
- `src/brats/assets/postgres-release-manifest.yml` — parameterized with `((pg-version))`
- `src/brats/acceptance/postgres_release_test.go` — version matrix tests
- `docs/postgres-migration.md` — operator migration guide

---

## Task 1: Deprecate postgres-13 job

**Files:**
- Modify: `jobs/postgres-13/spec`
- Modify: `jobs/postgres-13/templates/pre-start.erb`

- [ ] **Step 1: Add deprecation description to spec**

Open `jobs/postgres-13/spec` and replace the `name:` block at the top — add a `description` field immediately after `name`:

```yaml
---
name: postgres-13
description: "DEPRECATED: This job will be removed in the next bosh release. Use the postgres job from cloudfoundry/postgres-release instead. See docs/postgres-migration.md for upgrade instructions."
```

- [ ] **Step 2: Add deprecation warning to pre-start**

Open `jobs/postgres-13/templates/pre-start.erb`. After the shebang and before `set -eu`, insert:

```bash
echo "WARNING: The postgres-13 job is deprecated and will be removed in the next bosh release."
echo "WARNING: Migrate to cloudfoundry/postgres-release. See docs/postgres-migration.md"
```

- [ ] **Step 3: Verify templates render**

```bash
cd /Users/I539231/Projects/Workspaces/Upstream/bosh
bundle exec rspec spec/postgres_bpm_spec.rb
```

Expected: both postgres and postgres-13 examples still pass (we haven't touched bpm.yml).

- [ ] **Step 4: Commit**

```bash
git add jobs/postgres-13/spec jobs/postgres-13/templates/pre-start.erb
git commit -m "deprecate postgres-13 job: removal in next release"
```

---

## Task 2: Delete homegrown postgres job, packages, and blob-bumping CI

**Files:**
- Delete: `jobs/postgres/`
- Delete: `packages/postgres-15/`
- Delete: `packages/postgres-13/`
- Delete: `spec/postgres_bpm_spec.rb`
- Delete: `ci/tasks/bump-postgres-packages.yml`
- Delete: `ci/tasks/bump-postgres-packages.sh`
- Modify: `config/blobs.yml`

- [ ] **Step 1: Delete jobs/postgres and packages**

```bash
rm -rf jobs/postgres packages/postgres-15 packages/postgres-13
rm spec/postgres_bpm_spec.rb
rm ci/tasks/bump-postgres-packages.yml ci/tasks/bump-postgres-packages.sh
```

- [ ] **Step 2: Remove blob entries from config/blobs.yml**

Open `config/blobs.yml`. Remove all lines under the `postgres/` key — any entry whose path starts with `postgres/postgresql-`. Leave all other blob entries intact.

Verify the file is still valid YAML:

```bash
ruby -e "require 'yaml'; YAML.load_file('config/blobs.yml')"
```

Expected: no output (no error).

- [ ] **Step 3: Verify release can still be assembled**

```bash
bosh create-release --force 2>&1 | tail -20
```

Expected: release created successfully; no references to `postgres-15` or `postgres-13` packages.

- [ ] **Step 4: Commit**

```bash
git add -u
git add config/blobs.yml
git commit -m "remove postgres job, packages, and blob-bumping CI tasks"
```

---

## Task 3: Write migration docs

**Files:**
- Create: `docs/postgres-migration.md`

- [ ] **Step 1: Create the migration guide**

Create `docs/postgres-migration.md` with this content:

```markdown
# Migrating from bosh postgres jobs to cloudfoundry/postgres-release

## Background

The `postgres` and `postgres-13` jobs previously shipped inside the bosh release
have been removed. PostgreSQL is now provided by the
[cloudfoundry/postgres-release](https://github.com/cloudfoundry/postgres-release).

This release ships PostgreSQL versions 15, 16, 17, and 18.

## Switching from jobs/postgres (bosh release)

In your director manifest, replace:

```yaml
releases:
- name: bosh
  version: latest

instance_groups:
- name: bosh
  jobs:
  - name: postgres
    release: bosh
  properties:
    postgres:
      user: bosh
      password: secret
      database: bosh
      listen_address: 127.0.0.1
      port: 5432
      max_connections: 200
```

With:

```yaml
releases:
- name: bosh
  version: latest
- name: postgres
  url: https://bosh.io/d/github.com/cloudfoundry/postgres-release
  version: latest

instance_groups:
- name: bosh
  jobs:
  - name: postgres
    release: postgres
  properties:
    databases:
      version: 15        # match your existing on-disk data version
      port: 5432
      max_connections: 500
      databases:
      - name: bosh
      roles:
      - name: bosh
        password: secret
```

## Switching from jobs/postgres-13

Same as above, but set `databases.version: 13`.

## In-place cutover procedure

1. Set `databases.version: 15` (or 13 if still on postgres-13).
   postgres-release detects the existing `/var/vcap/store/postgres-<version>`
   data directory and starts without reinitializing.
2. Deploy. BOSH will restart the postgres process using postgres-release.
3. To upgrade to a newer PostgreSQL major version, change `databases.version`
   to 16, 17, or 18 and redeploy. postgres-release handles `pg_upgrade`.

## Property mapping

| Old (`bosh` release)         | New (`postgres-release`)          |
|------------------------------|-----------------------------------|
| `postgres.user`              | `databases.roles[0].name`         |
| `postgres.password`          | `databases.roles[0].password`     |
| `postgres.database`          | `databases.databases[0].name`     |
| `postgres.additional_databases` | additional `databases.databases` entries |
| `postgres.listen_address`    | `databases.address` (default `127.0.0.1`) |
| `postgres.port`              | `databases.port` (default `5432`) |
| `postgres.max_connections`   | `databases.max_connections` (default `500`) |
```

- [ ] **Step 2: Commit**

```bash
git add docs/postgres-migration.md
git commit -m "add postgres migration guide for operators"
```

---

## Task 4: Update BRATS manifests to use postgres-release

**Files:**
- Modify: `src/brats/assets/postgres-manifest.yml`
- Modify: `src/brats/assets/postgres-13-manifest.yml`
- Create: `src/brats/assets/postgres-release-manifest.yml`

- [ ] **Step 1: Update postgres-manifest.yml**

Replace the full content of `src/brats/assets/postgres-manifest.yml` with:

```yaml
---
name: ((deployment-name))
instance_groups:
- name: bosh
  azs: [z1]
  instances: 1
  jobs:
  - name: postgres
    release: postgres
  - name: bpm
    release: bpm
  vm_type: default
  stemcell: default
  persistent_disk_type: default
  networks:
  - name: default
  properties:
    databases:
      version: 15
      port: 5432
      databases:
      - name: bosh
      roles:
      - name: postgres
        password: c1oudc0w

stemcells:
- alias: default
  os: ((stemcell-os))
  version: latest

releases:
- name: bosh
  version: latest
- name: postgres
  version: latest
- name: bpm
  version: latest

update:
  canaries: 1
  max_in_flight: 10
  canary_watch_time: 1000-30000
  update_watch_time: 1000-30000
```

- [ ] **Step 2: Update postgres-13-manifest.yml**

Replace the full content of `src/brats/assets/postgres-13-manifest.yml` with:

```yaml
---
name: ((deployment-name))
instance_groups:
- name: bosh
  azs: [z1]
  instances: 1
  jobs:
  - name: postgres
    release: postgres
  - name: bpm
    release: bpm
  vm_type: default
  stemcell: default
  persistent_disk_type: default
  networks:
  - name: default
  properties:
    databases:
      version: 13
      port: 5432
      databases:
      - name: bosh
      roles:
      - name: postgres
        password: c1oudc0w

stemcells:
- alias: default
  os: ((stemcell-os))
  version: latest

releases:
- name: bosh
  version: "276.1.1"
  url: "https://bosh.io/d/github.com/cloudfoundry/bosh?v=276.1.1"
  sha1: "f9a625dd8a8fc6e01f1641390ced3ac0fee31523"
- name: postgres
  version: latest
- name: bpm
  version: latest

update:
  canaries: 1
  max_in_flight: 10
  canary_watch_time: 1000-30000
  update_watch_time: 1000-30000
```

- [ ] **Step 3: Create postgres-release-manifest.yml**

Create `src/brats/assets/postgres-release-manifest.yml`:

```yaml
---
name: ((deployment-name))
instance_groups:
- name: bosh
  azs: [z1]
  instances: 1
  jobs:
  - name: postgres
    release: postgres
  - name: bpm
    release: bpm
  vm_type: default
  stemcell: default
  persistent_disk_type: default
  networks:
  - name: default
  properties:
    databases:
      version: ((pg-version))
      port: 5432
      databases:
      - name: bosh
      roles:
      - name: postgres
        password: c1oudc0w

stemcells:
- alias: default
  os: ((stemcell-os))
  version: latest

releases:
- name: bosh
  version: latest
- name: postgres
  version: latest
- name: bpm
  version: latest

update:
  canaries: 1
  max_in_flight: 10
  canary_watch_time: 1000-30000
  update_watch_time: 1000-30000
```

- [ ] **Step 4: Validate YAML**

```bash
ruby -e "require 'yaml'; %w[postgres-manifest.yml postgres-13-manifest.yml postgres-release-manifest.yml].each { |f| YAML.load_file('src/brats/assets/' + f); puts \"#{f}: OK\" }"
```

Expected:
```
postgres-manifest.yml: OK
postgres-13-manifest.yml: OK
postgres-release-manifest.yml: OK
```

- [ ] **Step 5: Commit**

```bash
git add src/brats/assets/postgres-manifest.yml src/brats/assets/postgres-13-manifest.yml src/brats/assets/postgres-release-manifest.yml
git commit -m "update BRATS manifests to use postgres-release job and databases.* properties"
```

---

## Task 5: Update postgres_version_helper.rb

**Files:**
- Modify: `src/spec/integration_support/postgres_version_helper.rb`

The current implementation reads the postgres version from `jobs/postgres/spec` (which will no longer exist). Replace it to read from the `PG_VERSION` environment variable.

- [ ] **Step 1: Replace release_version method**

Open `src/spec/integration_support/postgres_version_helper.rb`. Replace the entire file content with:

```ruby
require 'integration_support/constants'

module IntegrationSupport
  class PostgresVersionHelper
    class << self
      def ensure_version_match!(env_db)
        return unless env_db == 'postgresql'

        unless local_major_version == configured_major_version
          raise "Postgres major version mismatch: PG_VERSION=#{configured_version}; local: #{local_version}."
        end
      end

      def local_major_version
        local_version.split('.')[0]
      end

      def local_version
        `postgres --version`.chomp.split(' ').last
      end

      def configured_major_version
        configured_version.split('.')[0]
      end

      def configured_version
        ENV.fetch('PG_VERSION') do
          raise 'PG_VERSION environment variable must be set when DB=postgresql'
        end
      end
    end
  end
end

RSpec.configure do |c|
  c.before(:suite) do
    IntegrationSupport::PostgresVersionHelper.ensure_version_match!(ENV['DB'])
  end
end
```

- [ ] **Step 2: Run the existing unit tests with PG_VERSION set**

```bash
cd /Users/I539231/Projects/Workspaces/Upstream/bosh
PG_VERSION=$(postgres --version | awk '{print $NF}') DB=postgresql bundle exec rspec src/spec/integration_support/ --dry-run 2>&1 | tail -5
```

Expected: no errors loading the file (dry-run just checks for syntax/load errors).

- [ ] **Step 3: Commit**

```bash
git add src/spec/integration_support/postgres_version_helper.rb
git commit -m "read postgres version from PG_VERSION env var instead of bosh job spec"
```

---

## Task 6: Write matrix BRATS test file

**Files:**
- Create: `src/brats/acceptance/postgres_release_test.go`

- [ ] **Step 1: Write the failing test skeleton**

Create `src/brats/acceptance/postgres_release_test.go`:

```go
package acceptance_test

import (
	"fmt"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

var _ = Describe("postgres-release version matrix", func() {
	const deployTimeout = 20 * time.Minute

	manifest := utils.AssetPath("postgres-release-manifest.yml")

	type pgEntry struct {
		version  int
		previous int
	}

	DescribeTable("PostgreSQL version",
		func(e pgEntry) {
			deploymentName := fmt.Sprintf("postgres-release-%d-%x", e.version, GinkgoT().RandomSeed())

			By(fmt.Sprintf("deploying postgres-release at version %d", e.version))
			session := utils.OuterBosh("deploy", "-n", manifest,
				"-d", deploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", deploymentName),
				"-v", fmt.Sprintf("pg-version=%d", e.version),
			)
			Eventually(session, deployTimeout).Should(gexec.Exit(0))

			if e.previous > 0 {
				By(fmt.Sprintf("upgrading from postgres-release version %d to %d", e.previous, e.version))
				previousDeploymentName := fmt.Sprintf("postgres-release-%d-to-%d-%x", e.previous, e.version, GinkgoT().RandomSeed())

				By(fmt.Sprintf("deploying at version %d first", e.previous))
				session = utils.OuterBosh("deploy", "-n", manifest,
					"-d", previousDeploymentName,
					"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
					"-v", fmt.Sprintf("deployment-name=%s", previousDeploymentName),
					"-v", fmt.Sprintf("pg-version=%d", e.previous),
				)
				Eventually(session, deployTimeout).Should(gexec.Exit(0))

				By(fmt.Sprintf("upgrading to version %d", e.version))
				session = utils.OuterBosh("deploy", "-n", manifest,
					"-d", previousDeploymentName,
					"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
					"-v", fmt.Sprintf("deployment-name=%s", previousDeploymentName),
					"-v", fmt.Sprintf("pg-version=%d", e.version),
				)
				Eventually(session, deployTimeout).Should(gexec.Exit(0))
			}
		},
		Entry("deploys version 15", pgEntry{version: 15}),
		Entry("upgrades 15 -> 16", pgEntry{version: 16, previous: 15}),
		Entry("upgrades 16 -> 17", pgEntry{version: 17, previous: 16}),
		Entry("upgrades 17 -> 18", pgEntry{version: 18, previous: 17}),
	)
})
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/I539231/Projects/Workspaces/Upstream/bosh/src/brats
go build ./acceptance/...
```

Expected: no compilation errors.

- [ ] **Step 3: Verify test names are discovered**

```bash
cd /Users/I539231/Projects/Workspaces/Upstream/bosh/src/brats
go test ./acceptance/... -v -list ".*" 2>&1 | grep "postgres-release"
```

Expected output includes entries like:
```
postgres-release version matrix PostgreSQL version deploys version 15
postgres-release version matrix PostgreSQL version upgrades 15 -> 16
postgres-release version matrix PostgreSQL version upgrades 16 -> 17
postgres-release version matrix PostgreSQL version upgrades 17 -> 18
```

- [ ] **Step 4: Commit**

```bash
git add src/brats/acceptance/postgres_release_test.go
git commit -m "add BRATS matrix tests for postgres-release versions 15/16/17/18"
```

---

## Task 7: Update CI Docker image and unit test jobs

**Files:**
- Modify: `ci/dockerfiles/main-postgres/Dockerfile`
- Modify: `ci/pipeline.yml`

- [ ] **Step 1: Remove postgres server package from Dockerfile**

Open `ci/dockerfiles/main-postgres/Dockerfile`. Remove the `"postgresql-${DB_VERSION}"` line (keep the client package):

```dockerfile
ARG BASE_IMAGE
FROM $BASE_IMAGE

ARG DB_VERSION

ENV DEBIAN_FRONTEND="noninteractive"
ENV PATH=${PATH}:"/usr/lib/postgresql/${DB_VERSION}/bin"

RUN echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list \
    && curl -sL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      | gpg --dearmor > /etc/apt/trusted.gpg.d/postgres-ACCC4CF8.gpg \
    && apt-get update \
    && apt-get install -y \
        libmysqlclient-dev \
        libpq-dev \
        libsqlite3-dev \
        "postgresql-client-${DB_VERSION}"

RUN sed -i 's/port = 5433/port = 5432/g' "/etc/postgresql/${DB_VERSION}/main/postgresql.conf" 2>/dev/null || true
```

Note: The `sed` line for `postgresql.conf` will no longer have a target file (server not installed), so add `|| true` to prevent a build error.

- [ ] **Step 2: Update pipeline.yml — remove postgres-13 jobs and resources, add postgres-17**

This is a multi-part edit to `ci/pipeline.yml`. Make each change described below.

**2a. In `groups[0].jobs` (the `bosh` group, lines ~15-32):**
- Remove `unit-director-postgres-13`
- Add `unit-director-postgres-17` after `unit-director-postgres-15`

**2b. In `groups[0].jobs` (delivery section, lines ~70-71):**
- Remove `unit-director-postgres-13`
- Add `unit-director-postgres-17` after `unit-director-postgres-15`
- Add `brats-postgres-15`, `brats-postgres-16`, `brats-postgres-17`, `brats-postgres-18`

**2c. In `groups[2].jobs` (the `container-images` group, lines ~47-48):**
- Remove `build-main-postgres-13`
- Add `build-main-postgres-17` after `build-main-postgres-15`

**2d. In `gate` job `serial_groups` (lines ~55-75):**
- Remove `unit-director-postgres-13`
- Add `unit-director-postgres-17`

**2e. Replace the `unit-director-postgres-13` job definition (lines ~205-227) with `unit-director-postgres-17`:**

```yaml
  - name: unit-director-postgres-17
    public: true
    serial: true
    serial_groups: [ unit-director-postgres-17 ]
    build_log_retention:
      builds: 250
    plan:
      - in_parallel:
          - get: bosh-ci
          - get: bosh
            passed: [ gate ]
            trigger: true
          - get: integration-postgres-17-image
      - task: test-rake-task
        file: bosh-ci/ci/tasks/test-rake-task.yml
        image: integration-postgres-17-image
        timeout: 2h
        privileged: true
        params:
          COVERAGE: false
          DB: postgresql
          PG_VERSION: "17"
          RAKE_TASK: spec:unit:director
```

**2f. Replace `build-main-postgres-13` job definition (lines ~1179-1211) with `build-main-postgres-17`:**

```yaml
  - name: build-main-postgres-17
    public: true
    serial: true
    plan:
      - get: bosh-ci-dockerfiles
      - get: integration-image
        trigger: true
        params:
          format: oci
      - task: build-image
        privileged: true
        config:
          platform: linux
          image_resource:
            type: registry-image
            source:
              repository: concourse/oci-build-task
          inputs:
            - name: bosh-ci-dockerfiles
            - name: integration-image
          outputs:
            - name: image
          params:
            CONTEXT: bosh-ci-dockerfiles/ci/dockerfiles/main-postgres
            BUILD_ARG_DB_VERSION: "17"
            IMAGE_ARG_BASE_IMAGE: integration-image/image.tar
          run:
            path: build
      - put: integration-postgres-17-image
        no_get: true
        params:
          image: image/image.tar
```

**2g. Also update `unit-director-postgres-15` to pass `PG_VERSION: "15"` in params** (it currently doesn't set it; add it to the `params` block of that job's `test-rake-task` step).

**2h. Add four new `brats-postgres-*` jobs** after the existing `brats-acceptance` job. Each job follows the same shape as `brats-acceptance` but passes `PG_VERSION` and runs only the `postgres-release` test:

```yaml
  - name: brats-postgres-15
    serial: true
    plan:
      - in_parallel:
          - get: bosh-ci
          - get: integration-image
          - get: bosh
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-dns-release
          - get: stemcell
            resource: warden-stemcell
          - get: director-stemcell
            resource: warden-stemcell
          - get: bosh-candidate-release-tarballs
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-release
            resource: bosh-candidate-release-tarballs
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-candidate-release-compiled
            trigger: true
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-deployment
          - get: docker-cpi-image
      - task: test-brats-postgres-15
        file: bosh-ci/ci/shared/brats/test-acceptance.yml
        image: docker-cpi-image
        privileged: true
        params:
          STEMCELL_OS: ubuntu-noble
          DIRECTOR_STEMCELL_OS: ubuntu-noble
          PG_VERSION: "15"
          BRATS_FOCUS_REGEXP: "postgres-release"

  - name: brats-postgres-16
    serial: true
    plan:
      - in_parallel:
          - get: bosh-ci
          - get: integration-image
          - get: bosh
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-dns-release
          - get: stemcell
            resource: warden-stemcell
          - get: director-stemcell
            resource: warden-stemcell
          - get: bosh-candidate-release-tarballs
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-release
            resource: bosh-candidate-release-tarballs
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-candidate-release-compiled
            trigger: true
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-deployment
          - get: docker-cpi-image
      - task: test-brats-postgres-16
        file: bosh-ci/ci/shared/brats/test-acceptance.yml
        image: docker-cpi-image
        privileged: true
        params:
          STEMCELL_OS: ubuntu-noble
          DIRECTOR_STEMCELL_OS: ubuntu-noble
          PG_VERSION: "16"
          BRATS_FOCUS_REGEXP: "postgres-release"

  - name: brats-postgres-17
    serial: true
    plan:
      - in_parallel:
          - get: bosh-ci
          - get: integration-image
          - get: bosh
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-dns-release
          - get: stemcell
            resource: warden-stemcell
          - get: director-stemcell
            resource: warden-stemcell
          - get: bosh-candidate-release-tarballs
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-release
            resource: bosh-candidate-release-tarballs
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-candidate-release-compiled
            trigger: true
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-deployment
          - get: docker-cpi-image
      - task: test-brats-postgres-17
        file: bosh-ci/ci/shared/brats/test-acceptance.yml
        image: docker-cpi-image
        privileged: true
        params:
          STEMCELL_OS: ubuntu-noble
          DIRECTOR_STEMCELL_OS: ubuntu-noble
          PG_VERSION: "17"
          BRATS_FOCUS_REGEXP: "postgres-release"

  - name: brats-postgres-18
    serial: true
    plan:
      - in_parallel:
          - get: bosh-ci
          - get: integration-image
          - get: bosh
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-dns-release
          - get: stemcell
            resource: warden-stemcell
          - get: director-stemcell
            resource: warden-stemcell
          - get: bosh-candidate-release-tarballs
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-release
            resource: bosh-candidate-release-tarballs
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-candidate-release-compiled
            trigger: true
            passed: [ create-bosh-candidate-release-compiled ]
          - get: bosh-deployment
          - get: docker-cpi-image
      - task: test-brats-postgres-18
        file: bosh-ci/ci/shared/brats/test-acceptance.yml
        image: docker-cpi-image
        privileged: true
        params:
          STEMCELL_OS: ubuntu-noble
          DIRECTOR_STEMCELL_OS: ubuntu-noble
          PG_VERSION: "18"
          BRATS_FOCUS_REGEXP: "postgres-release"
```

**2i. Replace `integration-postgres-13-image` resource definition (lines ~1962-1970) with `integration-postgres-17-image`:**

```yaml
  - name: integration-postgres-17-image
    type: registry-image
    source:
      repository: ghcr.io/cloudfoundry/bosh/main-postgres-17
      tag: *branch_name
      username: ((github_read_write_packages.username))
      password: ((github_read_write_packages.password))
```

- [ ] **Step 3: Validate pipeline YAML**

```bash
ruby -e "require 'yaml'; YAML.load_file('ci/pipeline.yml'); puts 'OK'"
```

Expected: `OK`

- [ ] **Step 4: Verify no stale references to postgres-13 image in pipeline**

```bash
grep -n "postgres-13-image\|build-main-postgres-13\|unit-director-postgres-13" ci/pipeline.yml
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add ci/dockerfiles/main-postgres/Dockerfile ci/pipeline.yml
git commit -m "add postgres-17 CI jobs/image, remove postgres-13, add brats-postgres-* matrix jobs"
```

---

## Task 8: Final verification

- [ ] **Step 1: Verify no stale references to removed jobs/packages remain**

```bash
grep -rn "jobs/postgres\b\|packages/postgres-13\|packages/postgres-15\|bump-postgres-packages" \
  --include="*.yml" --include="*.rb" --include="*.go" --include="*.md" \
  . 2>/dev/null | grep -v ".final_builds\|vendor\|releases/\|docs/postgres-migration\|docs/superpowers"
```

Expected: no output (or only references inside `releases/` historical snapshots and `docs/` which are intentional).

- [ ] **Step 2: Verify bosh release still assembles**

```bash
bosh create-release --force 2>&1 | grep -E "^(Release|Error|WARNING)" | head -20
```

Expected: `Release ... created successfully`. No errors about missing packages.

- [ ] **Step 3: Run unit tests for any touched Ruby files**

```bash
bundle exec rspec src/spec/integration_support/ 2>&1 | tail -10
```

Expected: all examples pass (or skip if DB != postgresql in this environment).

- [ ] **Step 4: Run BRATS Go compile check**

```bash
cd src/brats && go build ./... 2>&1
```

Expected: no errors.

- [ ] **Step 5: Commit**

If steps 1-4 required any fixups, commit them:

```bash
git add -u
git diff --cached --quiet || git commit -m "fix stale references after postgres-release migration"
```

---

## Self-Review Notes

- Task 1 covers spec → deprecation notice (Section 4 of spec)
- Task 2 covers all artifact deletions (Section 1)
- Task 3 covers docs/postgres-migration.md (Section 4)
- Task 4 covers manifest updates + new parameterized manifest (Sections 2, 3)
- Task 5 covers postgres_version_helper.rb update (Sections 2, 5)
- Task 6 covers the Go matrix test file (Section 3)
- Task 7 covers Dockerfile + all pipeline.yml changes (Sections 4, 5)
- Task 8 is end-to-end verification

**Known limitation:** The `brats-postgres-*` CI jobs reference `BRATS_FOCUS_REGEXP` to filter tests — this env var must be supported by `bosh-ci/ci/shared/brats/test-acceptance.yml` (a separate repo). If it isn't, the jobs will run the full BRATS suite rather than only the matrix tests. This is safe (not broken), just slower. Verify with the bosh-ci team before merging.
