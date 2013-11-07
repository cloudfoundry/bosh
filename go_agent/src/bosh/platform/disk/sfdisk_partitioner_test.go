package disk

import (
	testsys "bosh/system/testhelpers"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSfdiskPartition(t *testing.T) {
	fakeCmdRunner := &testsys.FakeCmdRunner{}
	fakeCmdRunner.CommandResults = map[string][]string{
		"sfdisk -d /dev/sda": []string{DEVSDA_SFDISK_EMPTY_DUMP, ""},
	}
	partitioner := NewSfdiskPartitioner(fakeCmdRunner)

	partitions := []Partition{
		{Type: PartitionTypeSwap, SizeInBlocks: 512},
		{Type: PartitionTypeLinux, SizeInBlocks: 1024},
		{Type: PartitionTypeLinux, SizeInBlocks: 512},
	}

	partitioner.Partition("/dev/sda", partitions)

	assert.Equal(t, 1, len(fakeCmdRunner.RunCommandsWithInput))
	assert.Equal(t, []string{",512,S\n,1024,L\n,,L\n", "sfdisk", "-uB", "/dev/sda"}, fakeCmdRunner.RunCommandsWithInput[0])
}

const DEVSDA_SFDISK_EMPTY_DUMP = `# partition table of /dev/sda
unit: sectors

/dev/sda1 : start=        0, size=    0, Id= 0
/dev/sda2 : start=        0, size=    0, Id= 0
/dev/sda3 : start=        0, size=    0, Id= 0
/dev/sda4 : start=        0, size=    0, Id= 0
`

func TestSfdiskGetDeviceSizeInBlocks(t *testing.T) {
	fakeCmdRunner := &testsys.FakeCmdRunner{}
	fakeCmdRunner.CommandResults = map[string][]string{
		"sfdisk -s /dev/sda": []string{"1234", ""},
	}
	partitioner := NewSfdiskPartitioner(fakeCmdRunner)

	size, err := partitioner.GetDeviceSizeInBlocks("/dev/sda")
	assert.NoError(t, err)

	assert.Equal(t, uint64(1234), size)
}

func TestSfdiskPartitionWhenPartitionsAlreadyMatch(t *testing.T) {
	fakeCmdRunner := &testsys.FakeCmdRunner{}
	fakeCmdRunner.CommandResults = map[string][]string{
		"sfdisk -d /dev/sda":  []string{DEVSDA_SFDISK_DUMP, ""},
		"sfdisk -s /dev/sda1": []string{"512", ""},
		"sfdisk -s /dev/sda2": []string{"1024", ""},
		"sfdisk -s /dev/sda3": []string{"512", ""},
	}

	partitioner := NewSfdiskPartitioner(fakeCmdRunner)

	partitions := []Partition{
		{Type: PartitionTypeSwap, SizeInBlocks: 512},
		{Type: PartitionTypeLinux, SizeInBlocks: 1024},
		{Type: PartitionTypeLinux, SizeInBlocks: 512},
	}

	partitioner.Partition("/dev/sda", partitions)

	assert.Equal(t, 0, len(fakeCmdRunner.RunCommandsWithInput))
}

const DEVSDA_SFDISK_DUMP = `# partition table of /dev/sda
unit: sectors

/dev/sda1 : start=        1, size= xxxx, Id=82
/dev/sda2 : start=     xxxx, size= xxxx, Id=83
/dev/sda3 : start=     xxxx, size= xxxx, Id=83
/dev/sda4 : start=        0, size=    0, Id= 0
`
