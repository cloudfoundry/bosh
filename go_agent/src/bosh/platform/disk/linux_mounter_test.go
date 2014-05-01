package disk_test

import (
	"errors"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/disk"
	fakedisk "bosh/platform/disk/fakes"
	fakesys "bosh/system/fakes"
)

type changingMountsSearcher struct {
	mounts [][]Mount
}

func (s *changingMountsSearcher) SearchMounts() ([]Mount, error) {
	result := s.mounts[0]
	s.mounts = s.mounts[1:]
	return result, nil
}

const swaponUsageOutput = `Filename				Type		Size	Used	Priority
/dev/swap                              partition	78180316	0	-1
`

const swaponUsageOutputWithOtherDevice = `Filename				Type		Size	Used	Priority
/dev/swap2                              partition	78180316	0	-1
`

var _ = Describe("linuxMounter", func() {
	var (
		runner         *fakesys.FakeCmdRunner
		mountsSearcher *fakedisk.FakeMountsSearcher
		mounter        Mounter
	)

	BeforeEach(func() {
		runner = fakesys.NewFakeCmdRunner()
		mountsSearcher = &fakedisk.FakeMountsSearcher{}
		mounter = NewLinuxMounter(runner, mountsSearcher, 1*time.Millisecond)
	})

	Describe("Mount", func() {
		It("allows to mount disk at given mount point", func() {
			err := mounter.Mount("/dev/foo", "/mnt/foo")
			Expect(err).ToNot(HaveOccurred())
			Expect(1).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"mount", "/dev/foo", "/mnt/foo"}))
		})

		It("does not try to mount disk again when disk is already mounted to the expected mount point", func() {
			mountsSearcher.SearchMountsMounts = []Mount{
				Mount{PartitionPath: "/dev/foo", MountPoint: "/mnt/foo"},
				Mount{PartitionPath: "/dev/bar", MountPoint: "/mnt/bar"},
			}

			err := mounter.Mount("/dev/foo", "/mnt/foo")
			Expect(err).ToNot(HaveOccurred())
			Expect(0).To(Equal(len(runner.RunCommands)))
		})

		It("returns error when disk is already mounted to the wrong mount point", func() {
			mountsSearcher.SearchMountsMounts = []Mount{
				Mount{PartitionPath: "/dev/foo", MountPoint: "/mnt/foobarbaz"},
				Mount{PartitionPath: "/dev/bar", MountPoint: "/mnt/bar"},
			}

			err := mounter.Mount("/dev/foo", "/mnt/foo")
			Expect(err).To(HaveOccurred())
			Expect(0).To(Equal(len(runner.RunCommands)))
		})

		It("returns error when another disk is already mounted to mount point", func() {
			mountsSearcher.SearchMountsMounts = []Mount{
				Mount{PartitionPath: "/dev/baz", MountPoint: "/mnt/foo"},
				Mount{PartitionPath: "/dev/bar", MountPoint: "/mnt/bar"},
			}

			err := mounter.Mount("/dev/foo", "/mnt/foo")
			Expect(err).To(HaveOccurred())
			Expect(0).To(Equal(len(runner.RunCommands)))
		})

		It("returns error and does not try to mount anything when searching mounts fails", func() {
			mountsSearcher.SearchMountsErr = errors.New("fake-search-mounts-err")

			err := mounter.Mount("/dev/foo", "/mnt/foo")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-search-mounts-err"))
			Expect(0).To(Equal(len(runner.RunCommands)))
		})
	})

	Describe("RemountAsReadonly", func() {
		It("remount as readonly", func() {
			changingMountsSearcher := &changingMountsSearcher{
				[][]Mount{
					[]Mount{Mount{PartitionPath: "/dev/baz", MountPoint: "/mnt/bar"}},
					[]Mount{Mount{PartitionPath: "/dev/baz", MountPoint: "/mnt/bar"}},
					[]Mount{},
				},
			}

			mounter := NewLinuxMounter(runner, changingMountsSearcher, 1*time.Millisecond)

			err := mounter.RemountAsReadonly("/mnt/bar")
			Expect(err).ToNot(HaveOccurred())
			Expect(2).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"umount", "/mnt/bar"}))
			Expect(runner.RunCommands[1]).To(Equal([]string{"mount", "/dev/baz", "/mnt/bar", "-o", "ro"}))
		})

		It("returns error and does not try to unmount/mount anything when searching mounts fails", func() {
			mountsSearcher.SearchMountsErr = errors.New("fake-search-mounts-err")

			err := mounter.RemountAsReadonly("/mnt/bar")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-search-mounts-err"))
			Expect(0).To(Equal(len(runner.RunCommands)))
		})
	})

	Describe("Remount", func() {
		It("remount", func() {
			changingMountsSearcher := &changingMountsSearcher{
				[][]Mount{
					[]Mount{Mount{PartitionPath: "/dev/baz", MountPoint: "/mnt/foo"}},
					[]Mount{Mount{PartitionPath: "/dev/baz", MountPoint: "/mnt/foo"}},
					[]Mount{},
				},
			}

			mounter := NewLinuxMounter(runner, changingMountsSearcher, 1*time.Millisecond)

			err := mounter.Remount("/mnt/foo", "/mnt/bar")
			Expect(err).ToNot(HaveOccurred())
			Expect(2).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"umount", "/mnt/foo"}))
			Expect(runner.RunCommands[1]).To(Equal([]string{"mount", "/dev/baz", "/mnt/bar"}))
		})

		It("returns error and does not try to unmount/mount anything when searching mounts fails", func() {
			mountsSearcher.SearchMountsErr = errors.New("fake-search-mounts-err")

			err := mounter.Remount("/mnt/foo", "/mnt/bar")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-search-mounts-err"))
			Expect(0).To(Equal(len(runner.RunCommands)))
		})
	})

	Describe("SwapOn", func() {
		It("linux swap on", func() {
			runner.AddCmdResult("swapon -s", fakesys.FakeCmdResult{Stdout: "Filename				Type		Size	Used	Priority\n"})

			mounter.SwapOn("/dev/swap")
			Expect(2).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[1]).To(Equal([]string{"swapon", "/dev/swap"}))
		})

		It("linux swap on when already on", func() {
			runner.AddCmdResult("swapon -s", fakesys.FakeCmdResult{Stdout: swaponUsageOutput})

			mounter.SwapOn("/dev/swap")
			Expect(1).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"swapon", "-s"}))
		})

		It("linux swap on when already on other device", func() {
			runner.AddCmdResult("swapon -s", fakesys.FakeCmdResult{Stdout: swaponUsageOutputWithOtherDevice})

			mounter.SwapOn("/dev/swap")
			Expect(2).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"swapon", "-s"}))
			Expect(runner.RunCommands[1]).To(Equal([]string{"swapon", "/dev/swap"}))
		})
	})

	Describe("Unmount", func() {
		BeforeEach(func() {
			mountsSearcher.SearchMountsMounts = []Mount{
				Mount{PartitionPath: "/dev/xvdb2", MountPoint: "/var/vcap/data"},
			}
		})

		It("unmounts based on partition when partition is mounted", func() {
			didUnmount, err := mounter.Unmount("/dev/xvdb2")
			Expect(err).ToNot(HaveOccurred())
			Expect(didUnmount).To(BeTrue())

			Expect(1).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"umount", "/dev/xvdb2"}))
		})

		It("unmount based on mount point when mount point is mounted", func() {
			didUnmount, err := mounter.Unmount("/var/vcap/data")
			Expect(err).ToNot(HaveOccurred())
			Expect(didUnmount).To(BeTrue())

			Expect(1).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"umount", "/var/vcap/data"}))
		})

		It("returns without an error indicating that nothing was unmounted when partition or mount point is not mounted", func() {
			didUnmount, err := mounter.Unmount("/dev/xvdb3")
			Expect(err).ToNot(HaveOccurred())
			Expect(didUnmount).To(BeFalse())

			Expect(0).To(Equal(len(runner.RunCommands)))
		})

		It("returns without an error after failing several times and then succeeding to unmount", func() {
			runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{Error: errors.New("fake-error")})
			runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{Error: errors.New("fake-error")})
			runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{})

			didUnmount, err := mounter.Unmount("/dev/xvdb2")
			Expect(err).ToNot(HaveOccurred())
			Expect(didUnmount).To(BeTrue())

			Expect(3).To(Equal(len(runner.RunCommands)))
			Expect(runner.RunCommands[0]).To(Equal([]string{"umount", "/dev/xvdb2"}))
			Expect(runner.RunCommands[1]).To(Equal([]string{"umount", "/dev/xvdb2"}))
			Expect(runner.RunCommands[2]).To(Equal([]string{"umount", "/dev/xvdb2"}))
		})

		It("returns error when it fails to unmount too many times", func() {
			runner.AddCmdResult("umount /dev/xvdb2", fakesys.FakeCmdResult{Error: errors.New("fake-error"), Sticky: true})

			_, err := mounter.Unmount("/dev/xvdb2")
			Expect(err).To(HaveOccurred())
		})

		It("returns error and does not try to unmount anything when searching mounts fails", func() {
			mountsSearcher.SearchMountsErr = errors.New("fake-search-mounts-err")

			_, err := mounter.Unmount("/dev/xvdb2")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-search-mounts-err"))
			Expect(0).To(Equal(len(runner.RunCommands)))
		})
	})

	Describe("IsMountPoint", func() {
		It("is mount point", func() {
			mountsSearcher.SearchMountsMounts = []Mount{
				Mount{PartitionPath: "/dev/xvdb2", MountPoint: "/var/vcap/data"},
			}

			isMountPoint, err := mounter.IsMountPoint("/var/vcap/data")
			Expect(err).ToNot(HaveOccurred())
			Expect(isMountPoint).To(BeTrue())

			isMountPoint, err = mounter.IsMountPoint("/var/vcap/store")
			Expect(err).ToNot(HaveOccurred())
			Expect(isMountPoint).To(BeFalse())
		})

		It("returns error when searching mounts fails", func() {
			mountsSearcher.SearchMountsErr = errors.New("fake-search-mounts-err")

			_, err := mounter.IsMountPoint("/var/vcap/store")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-search-mounts-err"))
		})
	})

	Describe("IsMounted", func() {
		It("is mounted", func() {
			mountsSearcher.SearchMountsMounts = []Mount{
				Mount{PartitionPath: "/dev/xvdb2", MountPoint: "/var/vcap/data"},
			}

			isMounted, err := mounter.IsMounted("/dev/xvdb2")
			Expect(err).ToNot(HaveOccurred())
			Expect(isMounted).To(BeTrue())

			isMounted, err = mounter.IsMounted("/var/vcap/data")
			Expect(err).ToNot(HaveOccurred())
			Expect(isMounted).To(BeTrue())

			isMounted, err = mounter.IsMounted("/var/foo")
			Expect(err).ToNot(HaveOccurred())
			Expect(isMounted).To(BeFalse())
		})

		It("returns error when searching mounts fails", func() {
			mountsSearcher.SearchMountsErr = errors.New("fake-search-mounts-err")

			_, err := mounter.IsMounted("/var/foo")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-search-mounts-err"))
		})
	})
})
