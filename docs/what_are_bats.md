# BOSH Acceptance Tests

BATs (BOSH Acceptance Tests) are the high level integration tests that test BOSH code from end to end. They run against deployed BOSH director and use BOSH CLI to perform requests. They exercise BOSH workflow (e.g. deploying for the first time, updating existing deployment, handling broken deployment). The assertions are made against commands exit status, output and state of VM after performing the command.

The main goal of BATs is to test combination of deployed director and stemcell. The director is being targeted, CLI uploads tested stemcell to it and runs deployments.