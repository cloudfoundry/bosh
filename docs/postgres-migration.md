# Migrating from jobs/postgres-13 to jobs/postgres

## Background

The `postgres-13` job shipped inside the bosh release is deprecated and will be
removed in the next release. The `postgres` job (PostgreSQL 15) is the
supported replacement.

## Switching from jobs/postgres-13 to jobs/postgres

The `postgres` job in the bosh release runs PostgreSQL 15 and handles the
major-version upgrade from 13 automatically.

Update your director manifest to replace the `postgres-13` job with `postgres`:

```yaml
instance_groups:
- name: bosh
  jobs:
  - name: postgres    # was: postgres-13
    release: bosh
```

No property changes are needed — both jobs share the same `postgres.*`
property namespace. On the first deploy, the `postgres` job detects the
existing `/var/vcap/store/postgres-13` data directory and runs `pg_upgrade`
to PostgreSQL 15 automatically.

# Moving to cloudfoundry/postgres-release

The director database will move from the postgres jobs in this release to
[cloudfoundry/postgres-release](https://github.com/cloudfoundry/postgres-release).
postgres-release runs alongside the existing jobs for a while, and the switch
happens only once it's proven to work.

The steps, each in its own PR:

1. Add BRATS tests that deploy postgres-release with PostgreSQL 15 to 18
   (`brats-postgres-15` to `brats-postgres-18`). They run in CI but don't
   block `delivery`. Nothing changes for operators.
2. Add the `brats-postgres-*` jobs to `delivery` once they're stable, and
   deprecate the `postgres` job.
3. Remove the `postgres-13` job.
4. Switch the director to postgres-release and remove the old postgres jobs
   and packages.

Until step 4, keep using the `postgres` job from this release.
