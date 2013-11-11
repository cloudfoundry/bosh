package disk

import (
	testsys "bosh/system/testhelpers"
	"fmt"
	"github.com/stretchr/testify/assert"
	"io/ioutil"
	"log"
	"testing"
)

func TestSfdiskPartition(t *testing.T) {
	fakeCmdRunner := &testsys.FakeCmdRunner{}
	fakeCmdRunner.CommandResults = map[string][]string{
		"sfdisk -d /dev/sda": []string{DEVSDA_SFDISK_EMPTY_DUMP, ""},
	}
	partitioner := NewSfdiskPartitioner(fakeCmdRunner)
	partitioner.logger = nullLogger()

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
	partitioner.logger = nullLogger()

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
		"sfdisk -s /dev/sda": []string{fmt.Sprintf("%d\n", 40000*1024), ""},
	}
	partitioner := NewSfdiskPartitioner(fakeCmdRunner)
	partitioner.logger = nullLogger()

	size, err := partitioner.GetDeviceSizeInMb("/dev/sda")
	assert.NoError(t, err)

	assert.Equal(t, uint64(40000), size)
}

func TestSfdiskPartitionWhenPartitionsAlreadyMatch(t *testing.T) {
	fakeCmdRunner := &testsys.FakeCmdRunner{}
	fakeCmdRunner.CommandResults = map[string][]string{
		"sfdisk -d /dev/sda":  []string{DEVSDA_SFDISK_DUMP, ""},
		"sfdisk -s /dev/sda1": []string{fmt.Sprintf("%d\n", 525*1024), ""},
		"sfdisk -s /dev/sda2": []string{fmt.Sprintf("%d\n", 1020*1024), ""},
		"sfdisk -s /dev/sda3": []string{fmt.Sprintf("%d\n", 500*1024), ""},
	}

	partitioner := NewSfdiskPartitioner(fakeCmdRunner)
	partitioner.logger = nullLogger()

	partitions := []Partition{
		{Type: PartitionTypeSwap, SizeInMb: 512},
		{Type: PartitionTypeLinux, SizeInMb: 1024},
		{Type: PartitionTypeLinux, SizeInMb: 512},
	}

	partitioner.Partition("/dev/sda", partitions)

	assert.Equal(t, 0, len(fakeCmdRunner.RunCommandsWithInput))
}

func nullLogger() *log.Logger {
	return log.New(ioutil.Discard, "", 0)
}

const DEVSDA_SFDISK_DUMP = `# partition table of /dev/sda
unit: sectors

/dev/sda1 : start=        1, size= xxxx, Id=82
/dev/sda2 : start=     xxxx, size= xxxx, Id=83
/dev/sda3 : start=     xxxx, size= xxxx, Id=83
/dev/sda4 : start=        0, size=    0, Id= 0
`
