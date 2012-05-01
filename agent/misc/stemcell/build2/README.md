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
specification_file=spec/stemcell-esxi.spec
settings_file=etc/settings.bash
$ bin/build_from_spec.sh $work_dir $specification_file $settings_file
```

Provided that the settings file does not contain any errors, or is
missing settings, this will create a build from beginning to end. It
uses the temporary directory in `$work_dir` as working directory and
executes the stages specified in `$specification_file` in order.

### Incremental build

When iterating on a build, it can be very costly to require a full build
from beginning to end on every change. This is why the stemcell builder
supports incremental builds.

Incremental builds are made possible by the experimental `btrfs` and its
file system snapshotting capabilities. Snapshots are leveraged to allow
for an incremental build process in the following way. After executing
the first stage, the builder takes the SHA1 of the files in the stage's
directory and appends it to a hash file in the working directory.
When the stage is executed a second time, the script checks if the stage
has already been executed and compared the SHA1 in the hash file to
the SHA1 on disk. When the two match, the stage can use its snapshot
instead of being executed again.

For subsequent stages, the following algorithm is executed, for some
first stage A and some second stage B:

1. Read hash file from snapshot of A.
2. Compute SHA1 of B.
3. Compare concatenation of 1. and 2. with the contents of the hash file
   in the snapshot of B (if it exists).
4.
  - If equal, skip execution of B and use its snapshot.
  - If not equal, remove snapshot of B and re-execute it.

This algorithm ensures a change in some stage will force a rebuild of
itself and all subsequent stages.

#### Prerequisites

To get started, install the `btrfs-tools` package from apt. This package
is available on 12.04. On 10.04, you can download the `btrfs-tools` deb
for 12.04 from [Launchpad][btrfs-deb] and install it.

[btrfs-deb]: https://launchpad.net/ubuntu/precise/+package/btrfs-tools

#### Creating a btrfs filesystem

Next, create a btrfs filesystem. The following will create a 10GB btrfs
mount via a loopback device:

```
img=/tmp/btrfs.img
dd if=/dev/zero of=$img bs=1M count=10k

sudo losetup -f $img
dev=$(sudo losetup -j $img | cut -d: -f1)

sudo mkfs.btrfs $dev

mnt=/tmp/mnt
mkdir -p $mnt
sudo mount $dev $mnt
```

#### Executing the build script

The build script can now be used just as for a full build. The
difference is that stages that don't need to be executed will be
skipped. The script automatically detects if the working directory is a
btrfs mount or not.

The btrfs filesystem will retain snapshots of every stage, and will
throw away snapshots of stages that need to be rebuild. Since per-stage
settings are stored in the stage's `assets/` directory, also changes in
its settings will trigger a rebuild of the stage.

```
work_dir=/tmp/mnt
specification_file=spec/stemcell-esxi.spec
settings_file=etc/settings.bash
$ sudo bin/build_from_spec.sh $work_dir $specification_file $settings_file
```

## Hacking

**Keep stages fully isolated.**
