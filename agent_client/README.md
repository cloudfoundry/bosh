# Ruby Client for Bosh Agent

This ruby library provides a client to interact with a bosh agent (the agent running on all bosh servers).

Currently, only HTTPS method is supported. That is, with this library you cannot currently interact with normal bosh deployment VMs which are running in NATS mode.

## Usage

If there is a bosh agent running in HTTPS mode on host `1.2.3.4`, port 6868, with username/password configured to `vcap` and `vcap`, then you can create a client object and interact with it:

``` ruby
api = Bosh::Agent::Client.create("https://1.2.3.4:6868", "user" => "vcap", "password" => "vcap")
api.ping
"pong"
```

There is also a simple CLI:

```
$ agent_client -m https://vcap:vcap@1.2.3.4:6868 ping
pong
```

### Compiling a package

A bosh agent can compile a package from a bosh release (such as [cf-release](github.com/cloudfoundry/cf-release) or [bosh-sample-release](https://github.com/cloudfoundry/bosh-sample-release)) and upload/store the compiled blob to a [blobstore](https://github.com/cloudfoundry/bosh/tree/master/blobstore_client#readme) (remote service or local filesystem).

This feature of a bosh agent is also used to create the microbosh stemcells (via the [package_compiler](https://github.com/cloudfoundry/bosh/tree/master/package_compiler) command).

### Apply a deployment spec

During `bosh deploy` the servers take on behaviors during deployment. In bosh vernacular, the bosh director is "applying a spec" to each server. It is the bosh agent for each server that receives this "apply a spec" request and then starts running the jobs on its server. Broken down, once its receives the `apply` request it then:

* downloads the required packages
* downloads the job templates for jobs to the run on its server
* binds deployment properties the `erb` templates and exports finished job files (monit start scripts, config files)
* starts monit, which in turn starts the jobs' start scripts

See the [example spec documentation](https://github.com/cloudfoundry/bosh/blob/agent_client_readme_apply_spec/agent_client/docs/example_specs/bosh-sample-release.md) for what an "apply spec" looks like in detail and how to get an your own apply spec from your own bosh deployments.
