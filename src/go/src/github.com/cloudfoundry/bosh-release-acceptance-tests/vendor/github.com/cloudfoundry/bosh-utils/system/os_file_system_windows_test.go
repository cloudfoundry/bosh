package system_test

import (
	"os"
	"path"
	"path/filepath"
	"syscall"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"io/ioutil"

	fsWrapper "github.com/charlievieth/fs"
)

var _ = Describe("Windows Specific tests", func() {
	It("HomeDir returns an error if 'username' is not the current user", func() {
		if !Windows {
			Skip("Windows only test")
		}
		osFs := createOsFs()

		_, err := osFs.HomeDir("Non-Existent User Name 1234")
		Expect(err).To(HaveOccurred())
	})

	It("can remove a directory long path", func() {
		osFs := createOsFs()

		rootPath, longPath := randLongPath()
		err := fsWrapper.MkdirAll(longPath, 0755)
		defer fsWrapper.RemoveAll(rootPath)
		Expect(err).ToNot(HaveOccurred())

		dstFile, err := ioutil.TempFile(`\\?\`+longPath, "")
		Expect(err).ToNot(HaveOccurred())

		dstPath := path.Join(longPath, filepath.Base(dstFile.Name()))
		defer os.Remove(dstPath)
		dstFile.Close()

		fileInfo, err := osFs.Stat(dstPath)
		Expect(fileInfo).ToNot(BeNil())
		Expect(os.IsNotExist(err)).To(BeFalse())

		err = osFs.RemoveAll(dstPath)
		Expect(err).ToNot(HaveOccurred())

		_, err = osFs.Stat(dstPath)
		Expect(os.IsNotExist(err)).To(BeTrue())
	})

	// Alert future developers that a previously unimplemented
	// function in the os package is now implemented on Windows.
	It("fails if os features are implemented in Windows", func() {
		Expect(os.Chown("", 0, 0)).To(Equal(&os.PathError{"chown", "", syscall.EWINDOWS}), "os.Chown")
		Expect(os.Lchown("", 0, 0)).To(Equal(&os.PathError{"lchown", "", syscall.EWINDOWS}), "os.Lchown")

		Expect(os.Getuid()).To(Equal(-1), "os.Getuid")
		Expect(os.Geteuid()).To(Equal(-1), "os.Geteuid")
		Expect(os.Getgid()).To(Equal(-1), "os.Getgid")
		Expect(os.Getegid()).To(Equal(-1), "os.Getegid")

		_, err := os.Getgroups()
		Expect(err).To(Equal(os.NewSyscallError("getgroups", syscall.EWINDOWS)))
	})
})
