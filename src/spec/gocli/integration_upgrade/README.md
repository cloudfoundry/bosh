These tests are for bosh upgrade scenarios. They are technically integration tests (uses Integration Sandbox) that modify some of the run parameters.
They work by pre-filling a saved state of the DB and blobstore and applying them before the start of a test.
The database is dropped and recreated for each test.

To write a new upgrade test, you need to choose the initial state of the test. This can be done by 
- Either using an already created state. Check src/spec/assets/upgrade/* for list of available initial states. 
- Or you can create a new state by following steps in src/spec/assets/upgrade/README.md.