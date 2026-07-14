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

| Old (`bosh` release)            | New (`postgres-release`)                     |
|---------------------------------|----------------------------------------------|
| `postgres.user`                 | `databases.roles[0].name`                    |
| `postgres.password`             | `databases.roles[0].password`                |
| `postgres.database`             | `databases.databases[0].name`                |
| `postgres.additional_databases` | additional `databases.databases` entries     |
| `postgres.listen_address`       | `databases.address` (default `127.0.0.1`)    |
| `postgres.port`                 | `databases.port` (default `5432`)            |
| `postgres.max_connections`      | `databases.max_connections` (default `500`)  |
