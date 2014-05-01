package disk_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/disk"
	fakedisk "bosh/platform/disk/fakes"
)

var _ = Describe("linuxBindMounter", func() {
	var (
		delegateErr     error
		delegateMounter *fakedisk.FakeMounter
		mounter         Mounter
	)

	BeforeEach(func() {
		delegateErr = errors.New("fake-err")
		delegateMounter = &fakedisk.FakeMounter{}
		mounter = NewLinuxBindMounter(delegateMounter)
	})

	Describe("Mount", func() {
		It("delegates to mounter and adds --bind option to mount as a bind-mount", func() {
			delegateMounter.MountErr = delegateErr

			err := mounter.Mount("fake-partition-path", "fake-mount-path", "fake-opt1")

			// Outputs
			Expect(err).To(Equal(delegateErr))

			// Inputs
			Expect(delegateMounter.MountPartitionPaths).To(Equal([]string{"fake-partition-path"}))
			Expect(delegateMounter.MountMountPoints).To(Equal([]string{"fake-mount-path"}))
			Expect(delegateMounter.MountMountOptions).To(Equal([][]string{{"fake-opt1", "--bind"}}))
		})
	})

	Describe("RemountAsReadonly", func() {
		It("does not delegate to mounter because remount with --bind does not work", func() {
			err := mounter.RemountAsReadonly("fake-path")
			Expect(err).To(BeNil())
			Expect(delegateMounter.RemountAsReadonlyCalled).To(BeFalse())
		})
	})

	Describe("Remount", func() {
		It("delegates to mounter and adds --bind option to mount as a bind-mount", func() {
			delegateMounter.RemountErr = delegateErr

			err := mounter.Remount("fake-from-path", "fake-to-path", "fake-opt1")

			// Outputs
			Expect(err).To(Equal(delegateErr))

			// Inputs
			Expect(delegateMounter.RemountFromMountPoint).To(Equal("fake-from-path"))
			Expect(delegateMounter.RemountToMountPoint).To(Equal("fake-to-path"))
			Expect(delegateMounter.RemountMountOptions).To(Equal([]string{"fake-opt1", "--bind"}))
		})
	})

	Describe("SwapOn", func() {
		It("delegates to mounter", func() {
			delegateMounter.SwapOnErr = delegateErr

			err := mounter.SwapOn("fake-path")

			// Outputs
			Expect(err).To(Equal(delegateErr))

			// Inputs
			Expect(delegateMounter.SwapOnPartitionPaths).To(Equal([]string{"fake-path"}))
		})
	})

	Describe("Unmount", func() {
		It("delegates to mounter", func() {
			delegateMounter.UnmountErr = delegateErr
			delegateMounter.UnmountDidUnmount = true

			didUnmount, err := mounter.Unmount("fake-device-path")

			// Outputs
			Expect(didUnmount).To(BeTrue())
			Expect(err).To(Equal(delegateErr))

			// Inputs
			Expect(delegateMounter.UnmountPartitionPathOrMountPoint).To(Equal("fake-device-path"))
		})
	})

	Describe("IsMountPoint", func() {
		It("delegates to mounter", func() {
			delegateMounter.IsMountPointErr = delegateErr
			delegateMounter.IsMountPointResult = true

			isMountPoint, err := mounter.IsMountPoint("fake-device-path")

			// Outputs
			Expect(isMountPoint).To(BeTrue())
			Expect(err).To(Equal(delegateErr))

			// Inputs
			Expect(delegateMounter.IsMountPointPath).To(Equal("fake-device-path"))
		})
	})

	Describe("IsMounted", func() {
		It("delegates to mounter", func() {
			delegateMounter.IsMountedErr = delegateErr
			delegateMounter.IsMountedResult = true

			isMounted, err := mounter.IsMounted("fake-device-path")

			// Outputs
			Expect(isMounted).To(BeTrue())
			Expect(err).To(Equal(delegateErr))

			// Inputs
			Expect(delegateMounter.IsMountedDevicePathOrMountPoint).To(Equal("fake-device-path"))
		})
	})
})
