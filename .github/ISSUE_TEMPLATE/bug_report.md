---
name: Bug report
about: Create a report to help us improve

---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior (example):
1. Deploy a bosh director on <IaaS> with <configuration options>
2. Upload <stemcell> and <cloud-config>
3. Deploy <manifest>
4. `bosh ssh` to a specific instance
5. Run <commands> on the vm to see the behavior

**Expected behavior**
A clear and concise description of what you expected to happen.

**Logs**
Logs are always helpful! Add logs to help explain your problem.

**Versions (please complete the following information):**
 - Infrastructure: [e.g. AWS, GCP, etc]
 - BOSH version [e.g. 266.7]
 - BOSH CLI version [e.g. 5.1.1]
 - Stemcell version [e.g. ubuntu-<CODE-NAME>/<VERSION>]
 - ... other versions of releases being used (BOSH DNS, Credhub, UAA, BPM, etc)

**Deployment info:**
If possible, share your (redacted) manifest and any ops files used to deploy
BOSH or any other releases on top of BOSH.

If you used any deployment strategy it'd be helpful to point it out and share as
much about it as possible (e.g.  bosh-deployment, PCF, genesis, spiff, etc)

**Additional context**
Add any other context about the problem here.
