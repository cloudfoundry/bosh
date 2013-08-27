# BOSH stemcell builder

The set of scripts in this directory is responsible for every step in
the process of building a BOSH stemcell, regardless of target hypervisor
or virtual machine format.

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

### Specification

The execution order of the different stages is defined in the
specification. The specification is just another Bash script that
contains calls to the `stage` function, and thereby defines the order in
which the different stages should be applied. Because it is a script,
stages may be executed conditionally or programmatically when needed.

## Usage

The stemcell builder comes with a build script that is used to combine
settings and specification into ordered execution of stages. This script
can both be used for one-off builds, and for incremental builds, both of
which will be briefly discussed in the following sections.

### One-off build

To create a full build, the build script can be used like this:

```
work_dir=$(mktemp -d)
specification_file=spec/stemcell-vsphere.spec
settings_file=etc/settings.bash
$ bin/build_from_spec.sh $work_dir $specification_file $settings_file
```

Provided that the settings file does not contain any errors, or is
missing settings, this will create a build from beginning to end. It
uses the temporary directory in `$work_dir` as working directory and
executes the stages specified in `$specification_file` in order.

## Hacking

**Keep stages fully isolated.**
