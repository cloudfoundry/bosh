// +build windows

package fs

import (
	"bytes"
	"errors"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"unsafe"
)

var volumeName string

// Determine if symlinks are supported on the current volume.
func init() {
	const FILE_SUPPORTS_HARD_LINKS = 0x00400000

	kernel32DLL := syscall.MustLoadDLL("Kernel32.dll")
	procGetVolumeInformation := kernel32DLL.MustFindProc("GetVolumeInformationW")

	wd, err := os.Getwd()
	if err != nil {
		panic(err)
	}
	volumeName = filepath.VolumeName(wd)
	vu, err := syscall.UTF16FromString(volumeName + `\`)
	if err != nil {
		panic(err)
	}
	var (
		VolumeSerialNumber     uint32
		MaximumComponentLength uint32
		FileSystemFlags        uint32
	)
	r1, _, err := procGetVolumeInformation.Call(
		uintptr(unsafe.Pointer(&vu[0])), 0, 0,
		uintptr(unsafe.Pointer(&VolumeSerialNumber)),
		uintptr(unsafe.Pointer(&MaximumComponentLength)),
		uintptr(unsafe.Pointer(&FileSystemFlags)), 0, 0,
	)
	if err != syscall.Errno(0) {
		panic(fmt.Errorf("Error: getting information for volume (%s): %s", volumeName, err))
	}
	if r1 == 0 {
		panic(errors.New("GetVolumeInformation: returned false without an error"))
	}
	supportsSymlinks = FileSystemFlags&FILE_SUPPORTS_HARD_LINKS != 0
}

func longPathName() string {
	var buf bytes.Buffer
	for i := 0; i < 2; i++ {
		for i := byte('A'); i <= 'Z'; i++ {
			buf.Write(bytes.Repeat([]byte{i}, 4))
			buf.WriteRune(filepath.Separator)
		}
	}
	return filepath.Clean(buf.String())
}

func tempDir(t *testing.T) string {
	path, err := ioutil.TempDir("", "fs-test")
	if err != nil {
		t.Fatal(err)
	}
	return path
}

func TestMkdir(t *testing.T) {
	temp := tempDir(t)

	n := MAX_PATH - len(temp) - len(string(os.PathSeparator)) - 1
	path := filepath.Join(temp, strings.Repeat("A", n))

	err := Mkdir(path, 0755)
	if err != nil {
		t.Fatal(err)
	}
	os.Remove(`\\?\` + path)
}

func TestMkdirAll(t *testing.T) {
	temp := tempDir(t)
	path := filepath.Join(temp, longPathName())

	err := MkdirAll(path, 0755)
	if err != nil {
		t.Fatalf("TestMkdirAll: %s", err)
	}
	defer os.RemoveAll(`\\?\` + temp)

	if _, err := Stat(path); err != nil {
		t.Fatalf("TestMkdirAll: Stat failed %s", err)
	}
	if _, err := Lstat(path); err != nil {
		t.Fatalf("TestMkdirAll: Stat failed %s", err)
	}

	// Make sure the handling of long paths is case-insensitive
	if _, err := Stat(strings.ToLower(path)); err != nil {
		t.Fatalf("TestMkdirAll: Stat failed %s", err)
	}
}

func TestRemoveAll(t *testing.T) {
	temp := tempDir(t)
	path := filepath.Join(temp, longPathName())

	err := MkdirAll(path, 0755)
	if err != nil {
		t.Fatalf("TestRemoveAll: %s", err)
	}
	defer os.RemoveAll(`\\?\` + temp)

	if err := RemoveAll(temp); err != nil {
		t.Fatalf("TestRemoveAll: %s", err)
	}
	if _, err := Stat(temp); !os.IsNotExist(err) {
		t.Fatalf("TestRemoveAll: failed to remove directory: %s", temp)
	}
	if _, err := Stat(path); !os.IsNotExist(err) {
		t.Fatalf("TestRemoveAll: failed to remove directory: %s", path)
	}
}

func TestLeadingSpace(t *testing.T) {
	const filename = " Leading Space.txt"
	path := filepath.Join("./testdata/", filename)
	f, err := Create(path)
	if err != nil {
		t.Fatal(err)
	}
	f.Close()
	defer os.Remove(path)

	fi, err := Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if name := fi.Name(); name != filename {
		t.Errorf("TestLeadingSpace (%s): invalid name %s", filename, name)
	}
}

func TestTrailingSpace(t *testing.T) {
	const filename = "Trailing Space.txt "
	path := filepath.Join("./testdata/", filename)
	f, err := Create(path)
	if err != nil {
		t.Fatal(err)
	}
	f.Close()
	defer os.Remove(path)

	fi, err := Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if name := fi.Name(); name != filename {
		t.Errorf("TestTrailingSpace (%s): invalid name %s", filename, name)
	}
}

func makeLongFilePath(t *testing.T) string {
	// 255 chars long, the common max component length.
	const a = "0123456789abcdefg"
	const s = a + a + a + a + a + a + a + a + a + a + a + a + a + a + a

	dir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}

	path := filepath.Join(dir, "testdata", s)

	f, err := Create(path)
	if err != nil {
		t.Fatalf("makeLongFilePath: error creating file (%s): %s", path, err)
	}
	f.Close()

	return path
}

func TestLongLeadingSlash(t *testing.T) {
	longpath := makeLongFilePath(t)
	defer os.RemoveAll(`\\?\` + longpath)

	// Remove volume name => \path\to\testdata
	testpath := strings.TrimPrefix(longpath, filepath.VolumeName(longpath))

	// Test with leading backslash
	if _, err := Stat(testpath); err != nil {
		t.Fatalf("TestLeadingSlash (%s): failed to open file (%s): %s", longpath, testpath, err)
	}

	// Test with forward slashes
	unixpath := strings.Replace(testpath, `\`, `/`, -1)
	if _, err := Stat(unixpath); err != nil {
		t.Fatalf("TestLeadingSlash (%s): failed to open file with forward slashes (%s): %s", longpath, unixpath, err)
	}
}

func TestLongRelativePaths(t *testing.T) {
	longpath := makeLongFilePath(t)
	defer os.RemoveAll(`\\?\` + longpath)

	// Remove volume name => \path\to\testdata
	testpath := strings.TrimPrefix(longpath, filepath.VolumeName(longpath))

	wd, err := os.Getwd()
	if err != nil {
		t.Error(err)
	}
	dirname := filepath.Base(wd)

	// Test relative path
	base := filepath.Base(testpath)
	relativePaths := []string{
		"testdata/" + base,
		"./testdata/" + base,
		"./testdata/../testdata/" + base,
		"../" + dirname + "/testdata/" + base,
		"../" + dirname + "/testdata/../testdata/" + base,
	}

	for _, relative := range relativePaths {
		if _, err := Stat(relative); err != nil {
			t.Fatalf("Relative path (%s): failed to open relative path (%s): %s",
				strings.TrimSuffix(relative, base), relative, err)
		}
	}
}

func TestLongTrailingSpace(t *testing.T) {
	longpath := makeLongFilePath(t)
	defer os.RemoveAll(`\\?\` + longpath)

	// test that trailing spaces are trimmed from long paths
	testpath := longpath + " "
	if _, err := Stat(testpath); err != nil {
		t.Fatalf("TestTrailingSpaceLongPath (%s): failed to open file (%s): %s", longpath, testpath, err)
	}

	// relative path with a trailing space
	relative := "./testdata/" + filepath.Base(longpath) + " "
	if _, err := Stat(relative); err != nil {
		t.Fatalf("TestTrailingSpaceLongPath (%s): failed to open relative path (%s): %s", longpath, relative, err)
	}
}

type pathTest struct {
	Path, Exp string
}

func (a pathTest) String() string {
	return fmt.Sprintf("{Path: %q Exp: %q}", a.Path, a.Exp)
}

func TestAbsPath(t *testing.T) {
	var tests = []pathTest{
		{`\a\\b\\c `, volumeName + `\a\b\c`},
		{`\\a\\b\\c `, volumeName + `\a\b\c`},
		{`\a\\b\\c `, volumeName + `\a\b\c`},
		{`\a\\b\\c`, volumeName + `\a\b\c`},
		{`\a\x\..\b`, volumeName + `\a\b`},
		{`\a\b\..\b\c`, volumeName + `\a\b\c`},
		{volumeName + `\a\\b\\c`, volumeName + `\a\b\c`},
		{volumeName + `\a\x\..\b`, volumeName + `\a\b`},
	}
	for _, x := range tests {
		p, err := absPath(x.Path)
		if err != nil {
			t.Fatal(err)
		}
		if p != x.Exp {
			t.Errorf("TestAbsPath (%+v): %q", x, p)
		}
	}
}

func TestWinPath(t *testing.T) {
	s := "0123456789abcdef"
	s = s + s + s + s + s + s + s + s + s + s + s + s + s + s
	var tests = []pathTest{
		// UNC paths and paths less than MAX_PATH should not be modified.
		{`\\server\\b\\c`, `\\server\\b\\c`},
		{`\\?\C:\\b\\c`, `\\?\C:\\b\\c`},
		{`\\C:\\b\\c`, `\\C:\\b\\c`},
		{`\\?\C:\` + s + `\..\` + s, `\\?\C:\` + s + `\..\` + s},

		// Non UNC paths longer than MAX_PATH should be converted to long paths.
		{`C:\\` + s + `\\` + s, `\\?\C:\` + s + `\` + s},
	}
	for _, x := range tests {
		p, err := winPath(x.Path)
		if err != nil {
			t.Fatal(err)
		}
		if p != x.Exp {
			t.Errorf("TestWinPath (%+v): %q", x, p)
		}
	}
}

// Make testing on Shared Folders easier, but do not allow the tests to pass
// unless the Soft and Hard link logic is exercised.
//
// To make testing output easier to read this should always be the last test.
//
// This MUST be the last Windows test we run.
func TestMustSupportSymlinks(t *testing.T) {
	const format = `
Hard links are not supported on the current volume (%s).
Therefore, all hard and soft link tests were skipped.

To make development on VMs easier this is the last test
we run, and if this is the only error the other tests
succeeded.

The most common reason for hard and soft links not
being supported are running the tests from a network
drive or 'Shared Folder'.  The easiest solution is to
run the tests from the HOMEDRIVE (%s).`

	homedrive := "typically, C:"
	if s := os.Getenv("HOMEDRIVE"); s != "" {
		homedrive = s
	}
	if !supportsSymlinks {
		t.Errorf(format, volumeName, homedrive)
	}
}

func BenchmarkAbsPath_Relative_Short(b *testing.B) {
	for i := 0; i < b.N; i++ {
		if _, err := absPath(`/a//b//c`); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkAbsPath_Relative_Long(b *testing.B) {
	const s = `/c/Users/Administrator//go/src//github.com/charlievieth/fs/../fs/testdata`
	for i := 0; i < b.N; i++ {
		if _, err := absPath(s); err != nil {
			b.Fatal(err)
		}
	}
}
