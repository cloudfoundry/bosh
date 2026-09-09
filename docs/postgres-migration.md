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
      max_connections: 200
      databases:
      - name: bosh
      roles:
      - name: bosh
        password: secret
```

## Switching from jobs/postgres-13

**PostgreSQL 13 is no longer supported by postgres-release.** You must upgrade to version 15 first.

**To upgrade from postgres-13 to postgres-release 15:**

1. In your director manifest, use the old `postgres-13` job from BOSH release 283.1.4 with its `postgres.*` properties:

   ```yaml
   releases:
   - name: bosh
     version: 283.1.4  # pinned to version with postgres-13 job
   
   instance_groups:
   - name: bosh
     jobs:
     - name: postgres-13
       release: bosh
     properties:
       postgres:
         user: bosh
         password: secret
         database: bosh
   ```

2. Once stable, upgrade to postgres-release 15 as described in the "In-place cutover procedure" section, setting `databases.version: 15`.

## In-place cutover procedure

**Important:** Backup your PostgreSQL data before migrating. Test the migration procedure in a non-production environment first.

1. Set `databases.version: 15` (or match your existing on-disk data version).
   postgres-release detects the existing `/var/vcap/store/postgres-<version>`
   data directory and starts without reinitializing.
2. Deploy. BOSH will restart the postgres process using postgres-release.
3. Verify the postgres process is healthy and databases are accessible.
4. To upgrade to a newer PostgreSQL major version, change `databases.version`
   to 16, 17, or 18 and redeploy. postgres-release handles `pg_upgrade`.
   Each major version upgrade performs an in-place data migration and can take
   several minutes depending on database size.

## Property mapping

| Old (`bosh` release)            | New (`postgres-release`)                     |
|---------------------------------|----------------------------------------------|
| `postgres.user`                 | `databases.roles[0].name`                    |
| `postgres.password`             | `databases.roles[0].password`                |
| `postgres.database`             | `databases.databases[0].name`                |
| `postgres.additional_databases` | additional `databases.databases` entries     |
| `postgres.listen_address`       | Not supported; postgres-release listens on all interfaces (0.0.0.0). Use firewall rules or trusted deployment networks to restrict access. |
| `postgres.port`                 | `databases.port` (default `5432`)            |
| `postgres.max_connections`      | `databases.max_connections` (default `500`)  |