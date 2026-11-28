# Migrating the director database to cloudfoundry/postgres-release

## Deprecation notice

Both PostgreSQL jobs shipped inside the bosh release are **deprecated**:

| Job           | PostgreSQL | Status     |
|---------------|------------|------------|
| `postgres-13` | 13         | deprecated |
| `postgres`    | 15         | deprecated |

Their replacement is the `postgres` job from
[cloudfoundry/postgres-release](https://github.com/cloudfoundry/postgres-release).
The `postgres-13` job and package are removed first, in their own change. The
`postgres` job and the `postgres-15` package are removed in the same change
that switches the director to postgres-release. There is no further
transition period.

Directors still on `postgres-13` first move to the bosh `postgres` job. On the
first deploy it finds `/var/vcap/store/postgres-13` and runs `pg_upgrade` to
PostgreSQL 15. From there, migrate to postgres-release as described below.

## Rollout of cloudfoundry/postgres-release

1. **Parallel validation (done).** CI runs the `brats-postgres-15/16/17/18`
   jobs against postgres-release: a fresh deploy, an upgrade from the previous
   major version, and a migration from the bosh `postgres` job. PostgreSQL 15
   is the default. The regular BRATS jobs exclude them
   (`LABEL_FILTER: "!postgres-release"`).
2. **Gating (current).** The `brats-postgres-*` jobs are in the `passed:`
   list of `delivery`, so no bosh release ships unless it works with
   postgres-release. The `postgres` job is deprecated.
3. **Remove `postgres-13`.** Delete `jobs/postgres-13` and
   `packages/postgres-13`, along with their CI jobs and images.
4. **Switch and drop.** Point the director at postgres-release (for example in
   bosh-deployment). In the same change, delete `jobs/postgres` and
   `packages/postgres-15`, along with their CI jobs and images.

## Migrating an existing director

The bosh `postgres` job keeps its data in `/var/vcap/store/postgres-15`.
postgres-release expects it in `/var/vcap/store/postgres/postgres-<version>`,
next to a `POSTGRES_DATA_VERSION` file. Without that file, postgres-release
creates a new, empty database. So swapping the job alone is **not** enough.

The bosh `postgres` job ships `bin/migrate-to-postgres-release` for this. It
stops all processes on the VM, checks that PostgreSQL was shut down cleanly
and moves the data into the postgres-release layout. It is a rename on the
same disk, so it is quick and needs no extra space. Both jobs use PostgreSQL
15.20, so postgres-release takes the data over as it is.

Take a backup first (for example with BBR). Then:

1. Make sure the director runs the bosh `postgres` job of a bosh release that
   ships the script.
2. On the director VM, run:

   ```shell
   sudo /var/vcap/jobs/postgres/bin/migrate-to-postgres-release
   ```

   All processes stay stopped afterwards.
3. Right away, deploy the director with the postgres-release job instead of
   the bosh `postgres` job, e.g. with an ops file like this:

   ```yaml
   - type: replace
     path: /instance_groups/name=bosh/jobs/name=postgres
     value:
       name: postgres
       release: postgres
       properties:
         databases:
           version: 15
           port: 5432
           databases:
           - name: bosh
           roles:
           - name: postgres
             password: ((postgres_password))

   - type: replace
     path: /releases/-
     value:
       name: postgres
       version: "57.1.3"
       url: https://bosh.io/d/github.com/cloudfoundry/postgres-release?v=57.1.3
       sha1: sha256:597269299a0c684043a104c3bd6f4b1e4388783f6ad730bc010736b339c35cbc
   ```

   Add every database from `postgres.additional_databases` (e.g. `uaa`,
   `credhub`) to `databases.databases`, and keep the role and password the
   director uses (`postgres.user` / `postgres.password`).

   `databases.version: 15` is the smallest step. A newer version also works:
   postgres-release then runs `pg_upgrade` during the deploy.

Note that postgres-release listens on all interfaces, while the bosh job
listened on `127.0.0.1` by default. Make sure port 5432 of the director is not
reachable from outside.

### Rolling back

Until postgres-release has been deployed, the move can be undone:

```shell
sudo /var/vcap/jobs/postgres/bin/migrate-to-postgres-release --rollback
sudo /var/vcap/bosh/bin/monit start all
```

If the bosh `postgres` job is deployed again while the data is moved, its
pre-start fails instead of creating an empty database, and asks for either the
postgres-release deploy or the rollback.

If the migration script was interrupted, run it again to finish the move, or
run it with `--rollback` to undo it.

The script records the latest checkpoint location of the database when it
moves the data. PostgreSQL writes a new checkpoint whenever it shuts down, so
once postgres-release has started the database, `--rollback` refuses to run,
even if postgres-release uses the same PostgreSQL version. Roll back by
restoring the backup instead.
