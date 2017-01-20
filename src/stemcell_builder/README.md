# BOSH Stemcell Builder

The set of scripts in this directory is responsible for every step in
the process of building a BOSH stemcell, regardless of target hypervisor
or virtual machine format.


## Usage

See [bosh-stemcell](../bosh-stemcell/README.md)


## Concepts

This section briefly outlines the different concepts used in the
structure of the stemcell builder.

### Stages

Every stage in the build process is placed in a different directory in
the `stages/` directory. These stages are 100% isolated and cannot
express dependency to other stages other than by convention.

The code that is executed when a stage is executed is contained in the
file `apply.sh` in the root of the stage's directory.

### Assets

Any assets that a stage may require to successfully execute should also
be placed in the stage's directory. By convention, this is the `assets/`
directory.

### Configuration

Stages may depend on external configuration to execute successfully.
Instead of configuring every stage independently, and in an ad-hoc
manner, a global configuration file can be seeded to every stage before
a build is started. This enables custom code in every stage to catch any
configuration errors early on, allowing the developer to correct these
errors without wasting time on a build that will fail. The code that is
responsible for taking in the seed configuration, and storing its own
configuration in its own path is `config.sh`. It is not necessary that
this file exists; stages without this file are assumed not to require
any configuration.
