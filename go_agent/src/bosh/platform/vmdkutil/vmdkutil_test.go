package vmdkutil_test

import (
	fakevmdk "bosh/platform/vmdk/fakes"
	. "bosh/platform/vmdkutil"
	fakesys "bosh/system/fakes"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Vmdkutil", func() {
	var (
		fs       *fakesys.FakeFileSystem
		vmdk     *fakevmdk.FakeVmdk
		vmdkutil VmdkUtil
	)

	BeforeEach(func() {
		fs = fakesys.NewFakeFileSystem()
		vmdk = fakevmdk.NewFakeVmdk(fs, "env", "fake env contents")
	})

	JustBeforeEach(func() {
		vmdkutil = NewVmdkUtil("/fake/settings/dir", fs, vmdk)
	})

	It("gets file contents from VMDK", func() {
		contents, err := vmdkutil.GetFileContents("env")
		Expect(err).NotTo(HaveOccurred())

		Expect(vmdk.Mounted).To(Equal(false))
		Expect(vmdk.MediaAvailable).To(Equal(false))
		Expect(fs.FileExists("/fake/settings/dir")).To(Equal(true))
		Expect(vmdk.MountMountPath).To(Equal("/fake/settings/dir"))

		Expect(contents).To(Equal([]byte("fake env contents")))
	})

})
