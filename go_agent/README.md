# BOSH Agent written in Go

    PATH=.../s3cli/out:$PATH bin/run -I dummy -P ubuntu

## Running locally

To start server locally:

    gem install nats
    nats-server

To subscribe:

    nats-sub '>' -s nats://localhost:4222

To publish:

    nats-pub agent.123-456-789 '{"method":"apply","arguments":[{"packages":[{"name":"package-name", "version":"package-version"}]}]}' -s nats://localhost:4222

## Blobstores

The Go Agent ships with 4 default blobstores:

- Local filesystem
- Dummy (for testing)
- S3
- DAV

You can, however, use custom blobstores by implementing a simple interface. For example, if you want to use a blobstore named "custom" you need to create an executable named `bosh-blobstore-custom` somewhere in `PATH`. This executable must conform to the following command line interface:

- `-c` flag that specifies a config file path (this will be passed to every call to the executable)
- must parse the config file in JSON format
- must respond to `get <blobID> <filename>` by placing the file identified by the blobID into the filename specified
- must respond to `put <filename> <blobID>` by storing the file at filename into the blobstore at the specified blobID

A full call might look like:

    bosh-blobstore-custom -c /var/vcap/bosh/etc/blobstore-custom.json get 2340958ddfg /tmp/my-cool-file

# Set up a workstation for development

Note: This guide assumes a few things:

- You are working out of your $HOME/workspace directory.
- You have git
- You have gcc (or an equivalent)
- You can install packages (brew, apt-get, or equivalent)

Clone and set up the BOSH repository:

- `git clone git@github.com:cloudfoundry/bosh.git` (this may take a while as the BOSH repo is very large)
- `cd bosh/go_agent`

From here on out we assume you're working in `~/workspace/bosh/go_agent`

- `git checkout develop` (you should always work on the develop branch, never master)
- `git submodule update --init --recursive`

Get Golang and its dependencies (Mac example, replace with your package manager of choice):

- `brew update`
- `brew install go`
- `brew install hg` (Go needs mercurial for the `go get` command)

Set up Go for BOSH Agent development:

- `export GOPATH=$GOPATH:$HOME/workspace/bosh/go_agent` (you may want to add this to your bash start up scripts)
- `go get code.google.com/p/go.tools/cmd/vet` (the vet tool is used during the test suite)

You should now be able to run the tests for the Go Agent:

- `bin/test`

At this point all the tests should be passing. If you encounter any issues, please document them and add solutions to this README.

## Using IntelliJ with Go and the BOSH Agent

- Install [IntelliJ 13](http://www.jetbrains.com/idea/download/index.html) (we are using 13.0.1 Build 133.331)
- Set up the latest Google Go plugin for IntelliJ by following [Ross Hale's blog post](http://pivotallabs.com/setting-google-go-plugin-intellij-idea-13-os-x-10-8-5/) (the plugin found in IntelliJ's repository is dated)
- Download and use the [improved keybindings](https://github.com/Pivotal-Boulder/IDE-Preferences) for IntelliJ (optional):
    - `git clone git@github.com:Pivotal-Boulder/IDE-Preferences.git`
    - `cd ~/Library/Preferences/IntelliJIdea13/keymaps`
    - `ln -sf ~/workspace/IDE-Preferences/IntelliJKeymap.xml`
    - In IntelliJ: Preferences -> Keymap -> Pick 'Mac OS X 10.5+ Improved'

Set up the Go Agent project in IntelliJ:

- Open the ~/workspace/bosh/go_agent project in IntelliJ.
- Set the Go SDK as the Project SDK: File -> Project Structure -> Project in left sidebar -> Set the Go SDK go1.2 SDK under Project SDK
- Set the Go SDK as the Modules SDK: Modules in left sidebar -> Dependencies tab -> Set the Go SDK for the Module SDK -> Apply, OK

You should now be able to run tests from within IntelliJ.

