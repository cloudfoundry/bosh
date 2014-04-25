package disk_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/disk"
	fakesys "bosh/system/fakes"
)

var _ = Describe("cmdMountsSeacher", func() {
	var (
		runner   *fakesys.FakeCmdRunner
		searcher MountsSearcher
	)

	BeforeEach(func() {
		runner = fakesys.NewFakeCmdRunner()
		searcher = NewCmdMountsSearcher(runner)
	})

	Describe("SearchMounts", func() {
		Context("when running command succeeds", func() {
			It("returns parsed mount information", func() {
				runner.AddCmdResult("mount", fakesys.FakeCmdResult{
					Stdout: `devpts on /dev/pts type devpts (rw,noexec,nosuid,gid=5,mode=0620)
tmpfs on /run type tmpfs (rw,noexec,nosuid,size=10%,mode=0755)
/dev/sda1 on /boot type ext2 (rw)
none on /tmp/warden/cgroup type tmpfs (rw)`,
				})

				mounts, err := searcher.SearchMounts()
				Expect(err).ToNot(HaveOccurred())
				Expect(mounts).To(Equal([]Mount{
					Mount{PartitionPath: "devpts", MountPoint: "/dev/pts"},
					Mount{PartitionPath: "tmpfs", MountPoint: "/run"},
					Mount{PartitionPath: "/dev/sda1", MountPoint: "/boot"},
					Mount{PartitionPath: "none", MountPoint: "/tmp/warden/cgroup"},
				}))
			})

			It("ignores empty lines", func() {
				runner.AddCmdResult("mount", fakesys.FakeCmdResult{
					Stdout: `

tmpfs on /run type tmpfs (rw,noexec,nosuid,size=10%,mode=0755)

/dev/sda1 on /boot type ext2 (rw)
`,
				})

				mounts, err := searcher.SearchMounts()
				Expect(err).ToNot(HaveOccurred())
				Expect(mounts).To(Equal([]Mount{
					Mount{PartitionPath: "tmpfs", MountPoint: "/run"},
					Mount{PartitionPath: "/dev/sda1", MountPoint: "/boot"},
				}))
			})
		})

		Context("when running mount command fails", func() {
			It("returns error", func() {
				runner.AddCmdResult("mount", fakesys.FakeCmdResult{
					Error: errors.New("fake-run-err"),
				})

				mounts, err := searcher.SearchMounts()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-run-err"))
				Expect(mounts).To(BeEmpty())
			})
		})
	})
})
