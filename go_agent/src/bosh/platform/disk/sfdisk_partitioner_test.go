package disk

import (
	boshlog "bosh/logger"
	fakesys "bosh/system/fakes"
	"fmt"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSfdiskPartition(t *testing.T) {
	runner := &fakesys.FakeCmdRunner{}
	runner.AddCmdResult("sfdisk -d /dev/sda", fakesys.FakeCmdResult{Stdout: DEVSDA_SFDISK_EMPTY_DUMP})
	partitioner := createSfdiskPartitionerForTests(runner)

	partitions := []Partition{
		{Type: PartitionTypeSwap, SizeInMb: 512},
		{Type: PartitionTypeLinux, SizeInMb: 1024},
		{Type: PartitionTypeLinux, SizeInMb: 512},
	}

	partitioner.Partition("/dev/sda", partitions)

	assert.Equal(t, 1, len(runner.RunCommandsWithInput))
	assert.Equal(t, []string{",512,S\n,1024,L\n,,L\n", "sfdisk", "-uM", "/dev/sda"}, runner.RunCommandsWithInput[0])
}

const DEVSDA_SFDISK_EMPTY_DUMP = `# partition table of /dev/sda
unit: sectors

/dev/sda1 : start=        0, size=    0, Id= 0
/dev/sda2 : start=        0, size=    0, Id= 0
/dev/sda3 : start=        0, size=    0, Id= 0
/dev/sda4 : start=        0, size=    0, Id= 0
`

func TestSfdiskPartitionWithNoPartitionTable(t *testing.T) {
	runner := &fakesys.FakeCmdRunner{}
	runner.AddCmdResult("sfdisk -d /dev/sda", fakesys.FakeCmdResult{Stderr: DEVSDA_SFDISK_NOTABLE_DUMP_STDERR})
	partitioner := createSfdiskPartitionerForTests(runner)

	partitions := []Partition{
		{Type: PartitionTypeSwap, SizeInMb: 512},
		{Type: PartitionTypeLinux, SizeInMb: 1024},
		{Type: PartitionTypeLinux, SizeInMb: 512},
	}

	partitioner.Partition("/dev/sda", partitions)

	assert.Equal(t, 1, len(runner.RunCommandsWithInput))
	assert.Equal(t, []string{",512,S\n,1024,L\n,,L\n", "sfdisk", "-uM", "/dev/sda"}, runner.RunCommandsWithInput[0])
}

const DEVSDA_SFDISK_NOTABLE_DUMP_STDERR = `
sfdisk: ERROR: sector 0 does not have an msdos signature
 /dev/sda: unrecognized partition table type
No partitions found`

func TestSfdiskGetDeviceSizeInMb(t *testing.T) {
	runner := &fakesys.FakeCmdRunner{}
	runner.AddCmdResult("sfdisk -s /dev/sda", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 40000*1024)})
	partitioner := createSfdiskPartitionerForTests(runner)

	size, err := partitioner.GetDeviceSizeInMb("/dev/sda")
	assert.NoError(t, err)

	assert.Equal(t, uint64(40000), size)
}

func TestSfdiskPartitionWhenPartitionsAlreadyMatch(t *testing.T) {
	runner := &fakesys.FakeCmdRunner{}
	runner.AddCmdResult("sfdisk -d /dev/sda", fakesys.FakeCmdResult{Stdout: DEVSDA_SFDISK_DUMP})
	runner.AddCmdResult("sfdisk -s /dev/sda", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 2048*1024)})
	runner.AddCmdResult("sfdisk -s /dev/sda1", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 525*1024)})
	runner.AddCmdResult("sfdisk -s /dev/sda2", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 1020*1024)})
	runner.AddCmdResult("sfdisk -s /dev/sda3", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 500*1024)})
	partitioner := createSfdiskPartitionerForTests(runner)

	partitions := []Partition{
		{Type: PartitionTypeSwap, SizeInMb: 512},
		{Type: PartitionTypeLinux, SizeInMb: 1024},
		{Type: PartitionTypeLinux, SizeInMb: 512},
	}

	partitioner.Partition("/dev/sda", partitions)

	assert.Equal(t, 0, len(runner.RunCommandsWithInput))
}

func TestSfdiskPartitionWithLastPartitionNotMatchingSize(t *testing.T) {
	runner := &fakesys.FakeCmdRunner{}
	runner.AddCmdResult("sfdisk -d /dev/sda", fakesys.FakeCmdResult{Stdout: DEVSDA_SFDISK_DUMP_ONE_PARTITION})
	runner.AddCmdResult("sfdisk -s /dev/sda", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 2048*1024)})
	runner.AddCmdResult("sfdisk -s /dev/sda1", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 1024*1024)})
	runner.AddCmdResult("sfdisk -s /dev/sda2", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 512*1024)})
	partitioner := createSfdiskPartitionerForTests(runner)

	partitions := []Partition{
		{Type: PartitionTypeLinux, SizeInMb: 1024},
		{Type: PartitionTypeLinux},
	}

	partitioner.Partition("/dev/sda", partitions)

	assert.Equal(t, 1, len(runner.RunCommandsWithInput))
	assert.Equal(t, []string{",1024,L\n,,L\n", "sfdisk", "-uM", "/dev/sda"}, runner.RunCommandsWithInput[0])
}

func TestSfdiskPartitionWithLastPartitionFillingDisk(t *testing.T) {
	runner := &fakesys.FakeCmdRunner{}
	runner.AddCmdResult("sfdisk -d /dev/sda", fakesys.FakeCmdResult{Stdout: DEVSDA_SFDISK_DUMP_ONE_PARTITION})
	runner.AddCmdResult("sfdisk -s /dev/sda", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 2048*1024)})
	runner.AddCmdResult("sfdisk -s /dev/sda1", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 1024*1024)})
	runner.AddCmdResult("sfdisk -s /dev/sda2", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 1024*1024)})

	partitioner := createSfdiskPartitionerForTests(runner)

	partitions := []Partition{
		{Type: PartitionTypeLinux, SizeInMb: 1024},
		{Type: PartitionTypeLinux},
	}

	partitioner.Partition("/dev/sda", partitions)

	assert.Equal(t, 0, len(runner.RunCommandsWithInput))
}

func createSfdiskPartitionerForTests(runner *fakesys.FakeCmdRunner) (partitioner sfdiskPartitioner) {
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	partitioner = newSfdiskPartitioner(logger, runner)
	return
}

const DEVSDA_SFDISK_DUMP = `# partition table of /dev/sda
unit: sectors

/dev/sda1 : start=        1, size= xxxx, Id=82
/dev/sda2 : start=     xxxx, size= xxxx, Id=83
/dev/sda3 : start=     xxxx, size= xxxx, Id=83
/dev/sda4 : start=        0, size=    0, Id= 0
`

const DEVSDA_SFDISK_DUMP_ONE_PARTITION = `# partition table of /dev/sda
unit: sectors

/dev/sda1 : start=        1, size= xxxx, Id=83
/dev/sda2 : start=     xxxx, size= xxxx, Id=83
/dev/sda3 : start=        0, size=    0, Id= 0
/dev/sda4 : start=        0, size=    0, Id= 0
`
