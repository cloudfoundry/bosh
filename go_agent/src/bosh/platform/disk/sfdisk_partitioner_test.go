package disk_test

import (
	boshlog "bosh/logger"
	. "bosh/platform/disk"
	fakesys "bosh/system/fakes"
	"fmt"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

const DEVSDA_SFDISK_EMPTY_DUMP = `# partition table of /dev/sda
unit: sectors

/dev/sda1 : start=        0, size=    0, Id= 0
/dev/sda2 : start=        0, size=    0, Id= 0
/dev/sda3 : start=        0, size=    0, Id= 0
/dev/sda4 : start=        0, size=    0, Id= 0
`

const DEVSDA_SFDISK_NOTABLE_DUMP_STDERR = `
sfdisk: ERROR: sector 0 does not have an msdos signature
 /dev/sda: unrecognized partition table type
No partitions found`

func createSfdiskPartitionerForTests(runner *fakesys.FakeCmdRunner) (partitioner Partitioner) {
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	partitioner = NewSfdiskPartitioner(logger, runner)
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

func init() {
	Describe("Testing with Ginkgo", func() {
		It("sfdisk partition", func() {
			runner := &fakesys.FakeCmdRunner{}
			runner.AddCmdResult("sfdisk -d /dev/sda", fakesys.FakeCmdResult{Stdout: DEVSDA_SFDISK_EMPTY_DUMP})
			partitioner := createSfdiskPartitionerForTests(runner)

			partitions := []Partition{
				{Type: PartitionTypeSwap, SizeInMb: 512},
				{Type: PartitionTypeLinux, SizeInMb: 1024},
				{Type: PartitionTypeLinux, SizeInMb: 512},
			}

			partitioner.Partition("/dev/sda", partitions)

			assert.Equal(GinkgoT(), 1, len(runner.RunCommandsWithInput))
			assert.Equal(GinkgoT(), []string{",512,S\n,1024,L\n,,L\n", "sfdisk", "-uM", "/dev/sda"}, runner.RunCommandsWithInput[0])
		})
		It("sfdisk partition with no partition table", func() {

			runner := &fakesys.FakeCmdRunner{}
			runner.AddCmdResult("sfdisk -d /dev/sda", fakesys.FakeCmdResult{Stderr: DEVSDA_SFDISK_NOTABLE_DUMP_STDERR})
			partitioner := createSfdiskPartitionerForTests(runner)

			partitions := []Partition{
				{Type: PartitionTypeSwap, SizeInMb: 512},
				{Type: PartitionTypeLinux, SizeInMb: 1024},
				{Type: PartitionTypeLinux, SizeInMb: 512},
			}

			partitioner.Partition("/dev/sda", partitions)

			assert.Equal(GinkgoT(), 1, len(runner.RunCommandsWithInput))
			assert.Equal(GinkgoT(), []string{",512,S\n,1024,L\n,,L\n", "sfdisk", "-uM", "/dev/sda"}, runner.RunCommandsWithInput[0])
		})
		It("sfdisk get device size in mb", func() {

			runner := &fakesys.FakeCmdRunner{}
			runner.AddCmdResult("sfdisk -s /dev/sda", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 40000*1024)})
			partitioner := createSfdiskPartitionerForTests(runner)

			size, err := partitioner.GetDeviceSizeInMb("/dev/sda")
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), uint64(40000), size)
		})
		It("sfdisk partition when partitions already match", func() {

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

			assert.Equal(GinkgoT(), 0, len(runner.RunCommandsWithInput))
		})
		It("sfdisk partition with last partition not matching size", func() {

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

			assert.Equal(GinkgoT(), 1, len(runner.RunCommandsWithInput))
			assert.Equal(GinkgoT(), []string{",1024,L\n,,L\n", "sfdisk", "-uM", "/dev/sda"}, runner.RunCommandsWithInput[0])
		})
		It("sfdisk partition with last partition filling disk", func() {

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

			assert.Equal(GinkgoT(), 0, len(runner.RunCommandsWithInput))
		})
	})
}
