package disk_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/disk"
	fakesys "bosh/system/fakes"
)

var _ = Describe("procMountsSearcher", func() {
	var (
		fs       *fakesys.FakeFileSystem
		searcher MountsSearcher
	)

	BeforeEach(func() {
		fs = fakesys.NewFakeFileSystem()
		searcher = NewProcMountsSearcher(fs)
	})

	Describe("SearchMounts", func() {
		Context("when reading /proc/mounts succeeds", func() {
			It("returns parsed mount information", func() {
				fs.WriteFileString(
					"/proc/mounts",
					`none /run/lock tmpfs rw,nosuid,nodev,noexec,relatime,size=5120k 0 0
none /run/shm tmpfs rw,nosuid,nodev,relatime 0 0
/dev/sda1 /boot ext2 rw,relatime,errors=continue 0 0
none /tmp/warden/cgroup tmpfs rw,relatime 0 0`,
				)

				mounts, err := searcher.SearchMounts()
				Expect(err).ToNot(HaveOccurred())
				Expect(mounts).To(Equal([]Mount{
					Mount{PartitionPath: "none", MountPoint: "/run/lock"},
					Mount{PartitionPath: "none", MountPoint: "/run/shm"},
					Mount{PartitionPath: "/dev/sda1", MountPoint: "/boot"},
					Mount{PartitionPath: "none", MountPoint: "/tmp/warden/cgroup"},
				}))
			})

			It("ignores empty lines", func() {
				fs.WriteFileString("/proc/mounts", `

none /run/shm tmpfs rw,nosuid,nodev,relatime 0 0

/dev/sda1 /boot ext2 rw,relatime,errors=continue 0 0
`,
				)

				mounts, err := searcher.SearchMounts()
				Expect(err).ToNot(HaveOccurred())
				Expect(mounts).To(Equal([]Mount{
					Mount{PartitionPath: "none", MountPoint: "/run/shm"},
					Mount{PartitionPath: "/dev/sda1", MountPoint: "/boot"},
				}))
			})
		})

		Context("when reading /proc/mounts fails", func() {
			It("returns error", func() {
				fs.WriteFileString("/proc/mounts", "")
				fs.ReadFileError = errors.New("fake-read-err")

				mounts, err := searcher.SearchMounts()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-read-err"))
				Expect(mounts).To(BeEmpty())
			})
		})
	})
})
