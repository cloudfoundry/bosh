package system_test

import (
	"bytes"
	"io/ioutil"
	"math/rand"
	"path/filepath"
	"runtime"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"testing"
)

const Windows = runtime.GOOS == "windows"

func TestSystem(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "System Suite")
}

var CatExePath string
var FalseExePath string
var WindowsExePath string

var _ = BeforeSuite(func() {
	var err error
	CatExePath, err = gexec.Build("exec_cmd_runner_fixtures/cat.go")
	Expect(err).ToNot(HaveOccurred())

	FalseExePath, err = gexec.Build("exec_cmd_runner_fixtures/false.go")
	Expect(err).ToNot(HaveOccurred())

	WindowsExePath, err = gexec.Build("exec_cmd_runner_fixtures/windows_exe.go")
	Expect(err).ToNot(HaveOccurred())
})

var _ = AfterSuite(func() {
	gexec.CleanupBuildArtifacts()
})

func randSeq(n int) string {
	const letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	rand.Seed(time.Now().UnixNano())
	b := make([]byte, n)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	return string(b)
}

// returns a long directory path rooted at a temp directory root.
// To cleanup delete the root directory.
func randLongPath() (root, path string) {
	tmpdir, err := ioutil.TempDir("", "")
	Expect(err).To(Succeed())
	volume := tmpdir + string(filepath.Separator)
	buf := bytes.NewBufferString(volume)
	for i := 0; i < 2; i++ {
		for i := byte('A'); i <= 'Z'; i++ {
			buf.Write(bytes.Repeat([]byte{i}, 4))
			buf.WriteRune(filepath.Separator)
		}
	}
	buf.WriteString(randSeq(10))
	buf.WriteRune(filepath.Separator)
	return tmpdir, filepath.Clean(buf.String())
}
