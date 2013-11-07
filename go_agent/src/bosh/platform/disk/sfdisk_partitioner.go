package disk

import (
	boshsys "bosh/system"
	"fmt"
	"strconv"
)

type sfdiskPartitioner struct {
	cmdRunner boshsys.CmdRunner
}

func NewSfdiskPartitioner(cmdRunner boshsys.CmdRunner) (partitioner sfdiskPartitioner) {
	partitioner.cmdRunner = cmdRunner
	return
}

func (p sfdiskPartitioner) Partition(devicePath string, partitions []Partition) (err error) {
	sfdiskPartitionTypes := map[PartitionType]string{
		PartitionTypeSwap:  "S",
		PartitionTypeLinux: "L",
	}

	sfdiskInput := ""
	for index, partition := range partitions {
		sfdiskPartitionType := sfdiskPartitionTypes[partition.Type]
		partitionSize := fmt.Sprintf("%d", partition.SizeInBlocks)

		if index == len(partitions)-1 {
			partitionSize = ""
		}

		sfdiskInput = sfdiskInput + fmt.Sprintf(",%s,%s\n", partitionSize, sfdiskPartitionType)
	}

	_, _, err = p.cmdRunner.RunCommandWithInput(sfdiskInput, "sfdisk", "-uB", devicePath)
	return
}

func (p sfdiskPartitioner) GetDeviceSizeInBlocks(devicePath string) (size uint64, err error) {
	stdout, _, err := p.cmdRunner.RunCommand("sfdisk", "-s", devicePath)
	if err != nil {
		return
	}

	intSize, err := strconv.Atoi(stdout)
	if err != nil {
		return
	}

	size = uint64(intSize)
	return
}
