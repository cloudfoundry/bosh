## How to snapshot the state of the director

To take snapshot of a director state, you'll need to take a snapshot of the database and the blobstore.  

#### Choose a director version and run an integration test
Usually you need to choose the state (git sha) of an already released director. Find that in the release section of the bosh github repo

- Clone the director repo somewhere 
- Checkout your chosen commit
- Run `bundle exec rake spec:integration:install_dependencies` from the src folder
- Create / Pick an integration test that will server as your utility to create the state
- In that integration test, make sure the state of all VMs created when taking the snapshot is set to **`hard stopped`**. Else it will fail!
- Put a sleep statement at the end of the test to have time to take a snapshot of the DB and blobstore (see next steps)

#### DB Snapshot
- While your test is sleeping, take a snapshot of the DB. For postgres use `pg_dump`, for  mysql `mysqldump` 
- The database name is logged when created
- You'll need to repeat this test for postgres and mysql. Recommendation is to use the CI docker image to spin up these DBs
- Save postgres SQL dump to a file named `postgres_db_snapshot.sql`
- Save mysql SQL dump to a file named `mysql_db_snapshot.sql`

#### Blobstore Snapshot
- While your test is sleeping, locate the blobstore path that is used by the test. Currently it is at `src/tmp/integration-tests-workspace/pid-xxxxx/sandbox/bosh_test_blobstore`
- Copy the contents of that directory and save them somewhere else
- You'll need to repeat this step for MYSQL and Postgres, because the UUIDs of the blobs will be randomly chosen in each case
- Compress blobstore contents while running postgres to a file with name `blobstore_snapshot_with_postgres.tar.gz`
- Compress blobstore contents while running mysql to a file with name `blobstore_snapshot_with_mysql.tar.gz`

#### Saving to spec/assets/upgrade 
After generating all the db and blobsore state files that are required

- Create a folder in `spec/assets/upgrade` with name `bosh-{version}-{commit-sha}`. This helps to track which version of the director the state was created from
- Create a README.md file in that folder to explain the state that was frozen
- This folder name will act as the initial state name of your test. For example : `with_reset_sandbox_before_each(test_initial_state: 'bosh-v260.6-f419326cad3e642ed4a5e6d893688c0766d7b259', drop_database: true)`

