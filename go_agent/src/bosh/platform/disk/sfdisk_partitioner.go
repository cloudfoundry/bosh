package disk

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshsys "bosh/system"
	"fmt"
	"strconv"
	"strings"
)

type sfdiskPartitioner struct {
	logger    boshlog.Logger
	cmdRunner boshsys.CmdRunner
	logTag    string
}

func NewSfdiskPartitioner(logger boshlog.Logger, cmdRunner boshsys.CmdRunner) (partitioner sfdiskPartitioner) {
	partitioner.logger = logger
	partitioner.cmdRunner = cmdRunner
	partitioner.logTag = "SfdiskPartitioner"
	return
}

func (p sfdiskPartitioner) Partition(devicePath string, partitions []Partition) (err error) {
	if p.diskMatchesPartitions(devicePath, partitions) {
		p.logger.Info(p.logTag, "%s already partitioned as expected, skipping", devicePath)
		return
	}

	sfdiskPartitionTypes := map[PartitionType]string{
		PartitionTypeSwap:  "S",
		PartitionTypeLinux: "L",
	}

	sfdiskInput := ""
	for index, partition := range partitions {
		sfdiskPartitionType := sfdiskPartitionTypes[partition.Type]
		partitionSize := fmt.Sprintf("%d", partition.SizeInMb)

		if index == len(partitions)-1 {
			partitionSize = ""
		}

		sfdiskInput = sfdiskInput + fmt.Sprintf(",%s,%s\n", partitionSize, sfdiskPartitionType)
	}
	p.logger.Info(p.logTag, "Partitioning %s with %s", devicePath, sfdiskInput)

	_, _, _, err = p.cmdRunner.RunCommandWithInput(sfdiskInput, "sfdisk", "-uM", devicePath)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to sfdisk")
	}
	return
}

func (p sfdiskPartitioner) GetDeviceSizeInMb(devicePath string) (size uint64, err error) {
	stdout, _, _, err := p.cmdRunner.RunCommand("sfdisk", "-s", devicePath)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to sfdisk")
		return
	}

	intSize, err := strconv.Atoi(strings.Trim(stdout, "\n"))
	if err != nil {
		err = bosherr.WrapError(err, "Converting disk size to integer")
		return
	}

	size = uint64(intSize) / uint64(1024)
	return
}

func (p sfdiskPartitioner) diskMatchesPartitions(devicePath string, partitionsToMatch []Partition) (result bool) {
	existingPartitions, err := p.getPartitions(devicePath)
	if err != nil {
		err = bosherr.WrapError(err, "Getting partitions for %s", devicePath)
		return
	}

	if len(existingPartitions) < len(partitionsToMatch) {
		return
	}

	remainingDiskSpace, err := p.GetDeviceSizeInMb(devicePath)
	if err != nil {
		err = bosherr.WrapError(err, "Getting device size for %s", devicePath)
		return
	}

	for index, partitionToMatch := range partitionsToMatch {
		if index == len(partitionsToMatch)-1 {
			partitionToMatch.SizeInMb = remainingDiskSpace
		}

		existingPartition := existingPartitions[index]
		switch {
		case existingPartition.Type != partitionToMatch.Type:
			return
		case notWithinDelta(existingPartition.SizeInMb, partitionToMatch.SizeInMb, 20):
			return
		}

		remainingDiskSpace = remainingDiskSpace - partitionToMatch.SizeInMb
	}

	return true
}

func notWithinDelta(left, right, delta uint64) bool {
	switch {
	case left-delta > right:
		return false
	case right-delta < left:
		return false
	}
	return true
}

func (p sfdiskPartitioner) getPartitions(devicePath string) (partitions []Partition, err error) {
	stdout, _, _, err := p.cmdRunner.RunCommand("sfdisk", "-d", devicePath)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to sfdisk")
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
			size, err := p.GetDeviceSizeInMb(partitionPath)
			if err == nil {
				partition.SizeInMb = size
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
