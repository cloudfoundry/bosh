package disk

import (
	boshlog "bosh/logger"
	fakesys "bosh/system/fakes"
	"fmt"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSfdiskPartition(t *testing.T) {
	cmdResults := map[string][]string{
		"sfdisk -d /dev/sda": []string{DEVSDA_SFDISK_EMPTY_DUMP, ""},
	}
	fakeCmdRunner, partitioner := createSfdiskPartitionerForTests(cmdResults)

	partitions := []Partition{
		{Type: PartitionTypeSwap, SizeInMb: 512},
		{Type: PartitionTypeLinux, SizeInMb: 1024},
		{Type: PartitionTypeLinux, SizeInMb: 512},
	}

	partitioner.Partition("/dev/sda", partitions)

	assert.Equal(t, 1, len(fakeCmdRunner.RunCommandsWithInput))
	assert.Equal(t, []string{",512,S\n,1024,L\n,,L\n", "sfdisk", "-uM", "/dev/sda"}, fakeCmdRunner.RunCommandsWithInput[0])
}

const DEVSDA_SFDISK_EMPTY_DUMP = `# partition table of /dev/sda
unit: sectors

/dev/sda1 : start=        0, size=    0, Id= 0
/dev/sda2 : start=        0, size=    0, Id= 0
/dev/sda3 : start=        0, size=    0, Id= 0
/dev/sda4 : start=        0, size=    0, Id= 0
`

func TestSfdiskPartitionWithNoPartitionTable(t *testing.T) {
	cmdResults := map[string][]string{
		"sfdisk -d /dev/sda": []string{"", DEVSDA_SFDISK_NOTABLE_DUMP_STDERR},
	}
	fakeCmdRunner, partitioner := createSfdiskPartitionerForTests(cmdResults)

	partitions := []Partition{
		{Type: PartitionTypeSwap, SizeInMb: 512},
		{Type: PartitionTypeLinux, SizeInMb: 1024},
		{Type: PartitionTypeLinux, SizeInMb: 512},
	}

	partitioner.Partition("/dev/sda", partitions)

	assert.Equal(t, 1, len(fakeCmdRunner.RunCommandsWithInput))
	assert.Equal(t, []string{",512,S\n,1024,L\n,,L\n", "sfdisk", "-uM", "/dev/sda"}, fakeCmdRunner.RunCommandsWithInput[0])
}

const DEVSDA_SFDISK_NOTABLE_DUMP_STDERR = `
sfdisk: ERROR: sector 0 does not have an msdos signature
 /dev/sda: unrecognized partition table type
No partitions found`

func TestSfdiskGetDeviceSizeInMb(t *testing.T) {
	cmdResults := map[string][]string{
		"sfdisk -s /dev/sda": []string{fmt.Sprintf("%d\n", 40000*1024), ""},
	}
	_, partitioner := createSfdiskPartitionerForTests(cmdResults)

	size, err := partitioner.GetDeviceSizeInMb("/dev/sda")
	assert.NoError(t, err)

	assert.Equal(t, uint64(40000), size)
}

func TestSfdiskPartitionWhenPartitionsAlreadyMatch(t *testing.T) {
	cmdResults := map[string][]string{
		"sfdisk -d /dev/sda":  []string{DEVSDA_SFDISK_DUMP, ""},
		"sfdisk -s /dev/sda1": []string{fmt.Sprintf("%d\n", 525*1024), ""},
		"sfdisk -s /dev/sda2": []string{fmt.Sprintf("%d\n", 1020*1024), ""},
		"sfdisk -s /dev/sda3": []string{fmt.Sprintf("%d\n", 500*1024), ""},
	}
	fakeCmdRunner, partitioner := createSfdiskPartitionerForTests(cmdResults)

	partitions := []Partition{
		{Type: PartitionTypeSwap, SizeInMb: 512},
		{Type: PartitionTypeLinux, SizeInMb: 1024},
		{Type: PartitionTypeLinux, SizeInMb: 512},
	}

	partitioner.Partition("/dev/sda", partitions)

	assert.Equal(t, 0, len(fakeCmdRunner.RunCommandsWithInput))
}

func createSfdiskPartitionerForTests(cmdResults map[string][]string) (cmdRunner *fakesys.FakeCmdRunner, partitioner sfdiskPartitioner) {
	cmdRunner = &fakesys.FakeCmdRunner{CommandResults: cmdResults}
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	partitioner = newSfdiskPartitioner(logger, cmdRunner)
	return
}

const DEVSDA_SFDISK_DUMP = `# partition table of /dev/sda
unit: sectors

/dev/sda1 : start=        1, size= xxxx, Id=82
/dev/sda2 : start=     xxxx, size= xxxx, Id=83
/dev/sda3 : start=     xxxx, size= xxxx, Id=83
/dev/sda4 : start=        0, size=    0, Id= 0
`
