package disk_test

import (
	"fmt"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshlog "bosh/logger"
	. "bosh/platform/disk"
	fakesys "bosh/system/fakes"
)

const devSdaSfdiskEmptyDump = `# partition table of /dev/sda
unit: sectors

/dev/sda1 : start=        0, size=    0, Id= 0
/dev/sda2 : start=        0, size=    0, Id= 0
/dev/sda3 : start=        0, size=    0, Id= 0
/dev/sda4 : start=        0, size=    0, Id= 0
`

const devSdaSfdiskNotableDumpStderr = `
sfdisk: ERROR: sector 0 does not have an msdos signature
 /dev/sda: unrecognized partition table type
No partitions found`

func createSfdiskPartitionerForTests(runner *fakesys.FakeCmdRunner) (partitioner Partitioner) {
	logger := boshlog.NewLogger(boshlog.LevelNone)
	partitioner = NewSfdiskPartitioner(logger, runner)
	return
}

const devSdaSfdiskDump = `# partition table of /dev/sda
unit: sectors

/dev/sda1 : start=        1, size= xxxx, Id=82
/dev/sda2 : start=     xxxx, size= xxxx, Id=83
/dev/sda3 : start=     xxxx, size= xxxx, Id=83
/dev/sda4 : start=        0, size=    0, Id= 0
`

const devSdaSfdiskDumpOnePartition = `# partition table of /dev/sda
unit: sectors

/dev/sda1 : start=        1, size= xxxx, Id=83
/dev/sda2 : start=     xxxx, size= xxxx, Id=83
/dev/sda3 : start=        0, size=    0, Id= 0
/dev/sda4 : start=        0, size=    0, Id= 0
`

func init() {
	Describe("Testing with Ginkgo", func() {
		It("sfdisk partition", func() {
			runner := fakesys.NewFakeCmdRunner()
			runner.AddCmdResult("sfdisk -d /dev/sda", fakesys.FakeCmdResult{Stdout: devSdaSfdiskEmptyDump})
			partitioner := createSfdiskPartitionerForTests(runner)

			partitions := []Partition{
				{Type: PartitionTypeSwap, SizeInMb: 512},
				{Type: PartitionTypeLinux, SizeInMb: 1024},
				{Type: PartitionTypeLinux, SizeInMb: 512},
			}

			partitioner.Partition("/dev/sda", partitions)

			Expect(1).To(Equal(len(runner.RunCommandsWithInput)))
			Expect(runner.RunCommandsWithInput[0]).To(Equal([]string{",512,S\n,1024,L\n,,L\n", "sfdisk", "-uM", "/dev/sda"}))
		})
		It("sfdisk partition with no partition table", func() {

			runner := fakesys.NewFakeCmdRunner()
			runner.AddCmdResult("sfdisk -d /dev/sda", fakesys.FakeCmdResult{Stderr: devSdaSfdiskNotableDumpStderr})
			partitioner := createSfdiskPartitionerForTests(runner)

			partitions := []Partition{
				{Type: PartitionTypeSwap, SizeInMb: 512},
				{Type: PartitionTypeLinux, SizeInMb: 1024},
				{Type: PartitionTypeLinux, SizeInMb: 512},
			}

			partitioner.Partition("/dev/sda", partitions)

			Expect(1).To(Equal(len(runner.RunCommandsWithInput)))
			Expect(runner.RunCommandsWithInput[0]).To(Equal([]string{",512,S\n,1024,L\n,,L\n", "sfdisk", "-uM", "/dev/sda"}))
		})
		It("sfdisk get device size in mb", func() {

			runner := fakesys.NewFakeCmdRunner()
			runner.AddCmdResult("sfdisk -s /dev/sda", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 40000*1024)})
			partitioner := createSfdiskPartitionerForTests(runner)

			size, err := partitioner.GetDeviceSizeInMb("/dev/sda")
			Expect(err).ToNot(HaveOccurred())

			Expect(uint64(40000)).To(Equal(size))
		})
		It("sfdisk partition when partitions already match", func() {

			runner := fakesys.NewFakeCmdRunner()
			runner.AddCmdResult("sfdisk -d /dev/sda", fakesys.FakeCmdResult{Stdout: devSdaSfdiskDump})
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

			Expect(0).To(Equal(len(runner.RunCommandsWithInput)))
		})
		It("sfdisk partition with last partition not matching size", func() {

			runner := fakesys.NewFakeCmdRunner()
			runner.AddCmdResult("sfdisk -d /dev/sda", fakesys.FakeCmdResult{Stdout: devSdaSfdiskDumpOnePartition})
			runner.AddCmdResult("sfdisk -s /dev/sda", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 2048*1024)})
			runner.AddCmdResult("sfdisk -s /dev/sda1", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 1024*1024)})
			runner.AddCmdResult("sfdisk -s /dev/sda2", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 512*1024)})
			partitioner := createSfdiskPartitionerForTests(runner)

			partitions := []Partition{
				{Type: PartitionTypeLinux, SizeInMb: 1024},
				{Type: PartitionTypeLinux},
			}

			partitioner.Partition("/dev/sda", partitions)

			Expect(1).To(Equal(len(runner.RunCommandsWithInput)))
			Expect(runner.RunCommandsWithInput[0]).To(Equal([]string{",1024,L\n,,L\n", "sfdisk", "-uM", "/dev/sda"}))
		})
		It("sfdisk partition with last partition filling disk", func() {

			runner := fakesys.NewFakeCmdRunner()
			runner.AddCmdResult("sfdisk -d /dev/sda", fakesys.FakeCmdResult{Stdout: devSdaSfdiskDumpOnePartition})
			runner.AddCmdResult("sfdisk -s /dev/sda", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 2048*1024)})
			runner.AddCmdResult("sfdisk -s /dev/sda1", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 1024*1024)})
			runner.AddCmdResult("sfdisk -s /dev/sda2", fakesys.FakeCmdResult{Stdout: fmt.Sprintf("%d\n", 1024*1024)})

			partitioner := createSfdiskPartitionerForTests(runner)

			partitions := []Partition{
				{Type: PartitionTypeLinux, SizeInMb: 1024},
				{Type: PartitionTypeLinux},
			}

			partitioner.Partition("/dev/sda", partitions)

			Expect(0).To(Equal(len(runner.RunCommandsWithInput)))
		})
	})
}
