# Design: Replace postgres/postgres-13 jobs with cloudfoundry/postgres-release

**Date:** 2026-07-02  
**Status:** Approved

## Summary

Replace the homegrown `postgres` and `postgres-13` BOSH jobs (and their compiled packages) in this repo with the upstream `cloudfoundry/postgres-release`. Add matrix-based validation tests covering all versions the release ships (15, 16, 17, 18). Deprecate `postgres-13` job with removal in the next release.

## Decisions

- **Property schema:** Hard cut to postgres-release schema (`databases.*`). No compatibility shim.
- **Migration strategy:** In-place cutover — postgres-release detects the existing `/var/vcap/store/postgres-15` data directory and starts without reinitializing. Operators set `databases.version: 15` first, then optionally bump to 16/17/18.
- **postgres-13 job:** Deprecated in this release (warning in spec + pre-start log), removed in the next.
- **Matrix versions:** 15, 16, 17, 18 — matching what postgres-release currently ships.
- **Test approach:** New Go test file with `DescribeTable` matrix + corresponding parallel Concourse jobs per version.

## Section 1: Removed artifacts

Deleted from this repo:

- `jobs/postgres/` — all templates, spec, monit
- `jobs/postgres-13/` — all templates, spec, monit (deprecation notice added before removal; removed next release)
- `packages/postgres-15/` — packaging script, spec, blobs
- `packages/postgres-13/` — packaging script, spec, blobs
- Corresponding entries in `config/blobs.yml`
- `spec/postgres_bpm_spec.rb` — tested bpm.yml rendering of both jobs (no replacement needed; postgres-release owns its bpm config)
- `ci/tasks/bump-postgres-packages.yml` and `bump-postgres-packages.sh` — blob-bumping automation
- `ci/dockerfiles/main-postgres/` — Docker images (replaced; see Section 5)

## Section 2: Manifest and property changes

`cloudfoundry/postgres-release` added as a peer release in all bosh director deployment manifests. The bosh-release `postgres` job co-location is replaced by the postgres-release `postgres` job.

### Property mapping

| Old (`bosh` release) | New (`postgres-release`) |
|---|---|
| `postgres.user` | `databases.roles[0].name` |
| `postgres.password` | `databases.roles[0].password` |
| `postgres.database` | `databases.databases[0].name` |
| `postgres.additional_databases` | additional entries in `databases.databases` |
| `postgres.listen_address` | `databases.address` (default `127.0.0.1`) |
| `postgres.port` | `databases.port` (default `5432`) |
| `postgres.max_connections` | `databases.max_connections` (default `500`) |
| _(implicit PG 15)_ | `databases.version: 15` (for in-place cutover) |

### In-place cutover

Operators migrating an existing director:
1. Set `databases.version: 15` — postgres-release detects `/var/vcap/store/postgres-15` and starts without reinitializing.
2. Optionally bump `databases.version` to 16, 17, or 18 in a subsequent deploy — postgres-release handles `pg_upgrade` internally.

### Affected files

- `src/brats/assets/postgres-manifest.yml` — `releases:` block gains a `postgres-release: latest` entry; job co-location changes from bosh-release `postgres` to postgres-release `postgres`; properties updated to `databases.*` schema
- `src/brats/assets/postgres-13-manifest.yml` — same release/job/property changes, with `databases.version: 13` pinned as the upgrade test baseline
- `src/spec/integration_support/postgres_version_helper.rb` — reads version from `PG_VERSION` env var instead of parsing bosh job packages list

## Section 3: Matrix validation tests

### New file: `src/brats/acceptance/postgres_release_test.go`

Version matrix covering 15, 16, 17, 18. Uses Ginkgo v2 `DescribeTable` + `Entry`. Each version gets:

1. **Fresh deploy** — deploy postgres-release at version N, verify BOSH director comes up healthy.
2. **Upgrade from N-1** — deploy at version N-1, redeploy at version N, verify data survives.

Adding a new version = one new `Entry` line.

Reuses existing `utils.OuterBosh` and `utils.AssetPath` helpers.

### New asset manifest: `src/brats/assets/postgres-release-manifest.yml`

Parameterized with `((pg-version))`. Single file covers all matrix entries. Existing `postgres-manifest.yml` and `postgres-13-manifest.yml` updated (not replaced) to satisfy existing `postgres_test.go`.

### New CI jobs in `pipeline.yml`

Four parallel Concourse jobs: `brats-postgres-15`, `brats-postgres-16`, `brats-postgres-17`, `brats-postgres-18`.

- Each passes `PG_VERSION` env var to the test runner.
- No serial group between them (run in parallel).
- Triggered by `create-bosh-candidate-release-compiled`.
- The existing `upgrade-postgres` CI job (which tests a full bosh director version upgrade) is **kept unchanged** — it tests director upgrade, not postgres version upgrade. The matrix jobs test postgres version upgrades within the same bosh release, which is a separate concern.

## Section 4: postgres-13 deprecation

**This release:**
- `jobs/postgres-13/spec` — `description` updated to: `"DEPRECATED: This job will be removed in the next bosh release. Use the postgres job from cloudfoundry/postgres-release instead. See docs/postgres-migration.md for upgrade instructions."`
- `jobs/postgres-13/templates/pre-start.erb` — adds `echo "WARNING: postgres-13 job is deprecated..."` so operators see it in BOSH logs.

**New doc: `docs/postgres-migration.md`**

Covers:
1. Why the change was made
2. Switching from bosh-release `jobs/postgres` → postgres-release `jobs/postgres`
3. Switching from `jobs/postgres-13` → postgres-release with `databases.version: 13`
4. In-place cutover procedure
5. Property mapping table

**CI:** `unit-director-postgres-13` and `build-main-postgres-13` Concourse jobs removed from `pipeline.yml`. `unit-director-postgres-15` kept for transition release.

## Section 5: CI Docker images

`ci/dockerfiles/main-postgres/Dockerfile` — remove the `postgresql-${DB_VERSION}` server package; keep `postgresql-client-${DB_VERSION}` and `libpq-dev`. The `ARG DB_VERSION` parametrization is kept.

**`pipeline.yml` changes:**
- `build-main-postgres-13` removed
- `build-main-postgres-17` added (new)
- `unit-director-postgres-13` removed
- `unit-director-postgres-17` added (new)

**`src/spec/integration_support/postgres_version_helper.rb`** — version check updated to read from `PG_VERSION` env var and validate against `psql --version`. Decouples from bosh job spec structure.

## Out of scope

- Updating `bosh-deployment` repo (separate repo; operators update their deployment manifests)
- High-availability postgres configurations
- External database support (RDS, GCP Cloud SQL) — unchanged
