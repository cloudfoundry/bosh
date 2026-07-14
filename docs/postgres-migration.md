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