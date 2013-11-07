package disk

import (
	testsys "bosh/system/testhelpers"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSfdiskPartition(t *testing.T) {
	fakeCmdRunner := &testsys.FakeCmdRunner{}
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
