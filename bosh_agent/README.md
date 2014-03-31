# Bosh agent

This project contains the Agent running on BOSH managed servers which is used by BOSH to orchestrate the behavior of a BOSH managed server.

The Agent performs the following tasks:

* mount any persistent disks assigned to its VM
* compile packages and upload result to blobstore
* apply a "spec" to install packages and 1+ job templates
* start & stop job processes via monit
* setup ssh connection

## Configuration

`bosh_agent` can be run in two configuration modes - infrastructure registry or CLI option overrides.

### Infrastructure registry configuration

`bosh_agent -c` attempts to load the config settings based on the infrastructure

For each different agent infrastructure:

* `bosh_agent -c -I aws` => attempts to load the config settings from an AWS registry; the registry HTTP address is provided to the bosh_agent via the [AWS user-data](https://github.com/cloudfoundry/bosh/blob/master/bosh_aws_cpi/lib/cloud/aws/instance_manager.rb#L159-L166)
* `bosh_agent -c -I vsphere` => attempts to load the config settings via a mounted fake cdrom
* `bosh_agent -c -I openstack`  => attempts to load the config settings from OpenStack registry (same as AWS registry - bosh-registry project folder); openstack user-data is provided by both user-data and a user-data.json file (the former isn't supported by Rackspace)

### CLI option overrides

Alternately, you can run `bosh_agent` without loading settings (without the `-c` flag).

* `bosh_agent` => uses the purely [default settings](https://github.com/cloudfoundry/bosh/blob/master/bosh_agent/bosh_agent#L9-22) from bosh_agent (defaults to NATS for communication & vsphere platform)
* `bosh_agent -n https://vcap:vcap@0.0.0.0:6868` => overrides default settings to tell `bosh_agent` to use https (as used by "bosh micro deploy")

Run `bosh_agent --help` to see all the CLI option overrides.

## API

When an agent is running is provides an API. By default, and within a normal bosh deployment, a bosh agent listens and responds to API requests via NATS. Alternately, it can be run to respond to HTTPS requests. See the section above for configuration.

### Agent API

The following commands (methods) are supported by each Agent (sent via NATS or the HTTP API):

* `apply`
  * `apply` - the agent's server is to become a job or upgrade to a new version of the job
* `compile_package`
  * `compile_package` - the agent is to download a package, compile it, and upload the results to the blobstore
* `disk`
  * `list_disk` - list disks mounted on agent's server
  * `migrate_disk` - copy data from an old disk to a new disk
  * `mount_disk` - mount a disk
  * `unmount_disk` - unmount a disk
* `drain`
  * `drain` - prepare the agent/job for shutdown
* `logs`
  * `fetch_logs` - package up and ship the current logs (job or agent or all)
* `ssh`
  * `ssh` - create a new ssh user, and set up an SSH connection or run a command; or cleanup a user
* `state`
  * `state` - a collection of information about the agent and the job

Methods that are implemented within `handler.rb`:

* `get_task` - poll for the results of a long running task
* `shutdown` - tell the agent to shutdown running processes (via monit)

Each supported method is a `Bosh::Agent::Message::XYZ` class.

### HTTPS client library

There is a Ruby client [agent_client](https://github.com/cloudfoundry/bosh/tree/master/agent_client) for communicating with an agent running the HTTPS API.

Currently it does not support NATS.

Its current use cases are within [bosh_cli_plugin_micro](https://github.com/cloudfoundry/bosh/tree/master/bosh_cli_plugin_micro) (the rubygem responsible for `bosh micro deploy`) and within the Micro Cloud Foundry [micro](https://github.com/cloudfoundry/micro) project.

### NATS pub/sub

Within a normal bosh deployment, a bosh agent is configured to listen on NATS for API requests.

Each agent publishes the following messages:

* `hm.agent.heartbeat.#{@agent_id}` - a heartbeat announcement
* `hm.agent.alert.#{@agent_id}` - system alerts
* `hm.agent.shutdown.#{@agent_id}` - shutdown announcement

Each agent subscribes to the following messages:

* `agent.#{@agent_id}` - for direct communication with a specific Agent for the API requests above.

