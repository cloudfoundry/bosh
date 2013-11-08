package disk

import (
	boshsys "bosh/system"
	"fmt"
	"strconv"
	"strings"
)

type sfdiskPartitioner struct {
	cmdRunner boshsys.CmdRunner
}

func NewSfdiskPartitioner(cmdRunner boshsys.CmdRunner) (partitioner sfdiskPartitioner) {
	partitioner.cmdRunner = cmdRunner
	return
}

func (p sfdiskPartitioner) Partition(devicePath string, partitions []Partition) (err error) {
	if p.diskMatchesPartitions(devicePath, partitions) {
		return
	}

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

	intSize, err := strconv.Atoi(strings.Trim(stdout, "\n"))
	if err != nil {
		return
	}

	size = uint64(intSize)
	return
}

func (p sfdiskPartitioner) diskMatchesPartitions(devicePath string, partitionsToMatch []Partition) (result bool) {
	existingPartitions, err := p.getPartitions(devicePath)
	if err != nil {
		return
	}

	if len(existingPartitions) < len(partitionsToMatch) {
		return
	}

	for index, partitionToMatch := range partitionsToMatch {
		existingPartition := existingPartitions[index]
		if existingPartition != partitionToMatch {
			return
		}
	}

	return true
}

func (p sfdiskPartitioner) getPartitions(devicePath string) (partitions []Partition, err error) {
	stdout, _, err := p.cmdRunner.RunCommand("sfdisk", "-d", devicePath)
	if err != nil {
		return
	}

	allLines := strings.Split(stdout, "\n")
	if len(allLines) < 4 {
		return
	}

	partitionLines := allLines[3 : len(allLines)-1]

	for _, partitionLine := range partitionLines {
		partitionPath, partitionType := extractPartitionPathAndType(partitionLine)
		partition := Partition{Type: partitionType}

		if partition.Type != PartitionTypeEmpty {
			size, err := p.GetDeviceSizeInBlocks(partitionPath)
			if err == nil {
				partition.SizeInBlocks = size
			}
		}

		partitions = append(partitions, partition)
	}
	return
}

var partitionTypesMap = map[string]PartitionType{
	"82": PartitionTypeSwap,
	"83": PartitionTypeLinux,
	"0":  PartitionTypeEmpty,
}

func extractPartitionPathAndType(line string) (partitionPath string, partitionType PartitionType) {
	partitionFields := strings.Fields(line)
	lastField := partitionFields[len(partitionFields)-1]

	sfdiskPartitionType := strings.Replace(lastField, "Id=", "", 1)

	partitionPath = partitionFields[0]
	partitionType = partitionTypesMap[sfdiskPartitionType]
	return
}
