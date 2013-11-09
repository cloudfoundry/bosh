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
	fakeCmdRunner := &testsys.FakeCmdRunner{}
	fakeCmdRunner.CommandResults = map[string][]string{
		"sfdisk -d /dev/sda": []string{"", DEVSDA_SFDISK_NOTABLE_DUMP_STDERR},
	}
	partitioner := NewSfdiskPartitioner(fakeCmdRunner)

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
	fakeCmdRunner := &testsys.FakeCmdRunner{}
	fakeCmdRunner.CommandResults = map[string][]string{
		"sfdisk -s /dev/sda": []string{"40960000\n", ""}, // 41943040000
	}
	partitioner := NewSfdiskPartitioner(fakeCmdRunner)

	size, err := partitioner.GetDeviceSizeInMb("/dev/sda")
	assert.NoError(t, err)

	assert.Equal(t, uint64(40000), size)
}

func TestSfdiskPartitionWhenPartitionsAlreadyMatch(t *testing.T) {
	fakeCmdRunner := &testsys.FakeCmdRunner{}
	fakeCmdRunner.CommandResults = map[string][]string{
		"sfdisk -d /dev/sda":  []string{DEVSDA_SFDISK_DUMP, ""},
		"sfdisk -s /dev/sda1": []string{"524288\n", ""},
		"sfdisk -s /dev/sda2": []string{"1048576\n", ""},
		"sfdisk -s /dev/sda3": []string{"524288\n", ""},
	}

	partitioner := NewSfdiskPartitioner(fakeCmdRunner)

	partitions := []Partition{
		{Type: PartitionTypeSwap, SizeInMb: 512},
		{Type: PartitionTypeLinux, SizeInMb: 1024},
		{Type: PartitionTypeLinux, SizeInMb: 512},
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
