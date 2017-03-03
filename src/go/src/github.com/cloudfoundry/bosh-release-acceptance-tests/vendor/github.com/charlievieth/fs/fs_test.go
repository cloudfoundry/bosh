/*
  The below code contains portions of the Go standard library, specically
  the os package.

  Copyright (c) 2009 The Go Authors. All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are
  met:

     * Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above
  copyright notice, this list of conditions and the following disclaimer
  in the documentation and/or other materials provided with the
  distribution.
     * Neither the name of Google Inc. nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

package fs

import (
	"bytes"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"syscall"
	"testing"
)

// On Windows this is determined during program initialization.
var supportsSymlinks = true

var dot = []string{
	"dir_unix.go",
	"env.go",
	"error.go",
	"file.go",
	"os_test.go",
	"types.go",
	"stat_darwin.go",
	"stat_linux.go",
}

type sysDir struct {
	name  string
	files []string
}

var sysdir = func() *sysDir {
	switch runtime.GOOS {
	case "android":
		return &sysDir{
			"/system/etc",
			[]string{
				"audio_policy.conf",
				"system_fonts.xml",
			},
		}
	case "darwin":
		switch runtime.GOARCH {
		case "arm", "arm64":
			wd, err := syscall.Getwd()
			if err != nil {
				wd = err.Error()
			}
			return &sysDir{
				filepath.Join(wd, "..", ".."),
				[]string{
					"ResourceRules.plist",
					"Info.plist",
				},
			}
		}
	case "windows":
		return &sysDir{
			os.Getenv("SystemRoot") + "\\system32\\drivers\\etc",
			[]string{
				"networks",
				"protocol",
				"services",
			},
		}
	case "plan9":
		return &sysDir{
			"/lib/ndb",
			[]string{
				"common",
				"local",
			},
		}
	}
	return &sysDir{
		"/etc",
		[]string{
			"group",
			"hosts",
			"passwd",
		},
	}
}()

func size(name string, t *testing.T) int64 {
	file, err := Open(name)
	if err != nil {
		t.Fatal("open failed:", err)
	}
	defer file.Close()
	var buf [100]byte
	len := 0
	for {
		n, e := file.Read(buf[0:])
		len += n
		if e == io.EOF {
			break
		}
		if e != nil {
			t.Fatal("read failed:", err)
		}
	}
	return int64(len)
}

func equal(name1, name2 string) (r bool) {
	switch runtime.GOOS {
	case "windows":
		r = strings.ToLower(name1) == strings.ToLower(name2)
	default:
		r = name1 == name2
	}
	return
}

// localTmp returns a local temporary directory not on NFS.
func localTmp() string {
	switch runtime.GOOS {
	case "android", "windows":
		return os.TempDir()
	case "darwin":
		switch runtime.GOARCH {
		case "arm", "arm64":
			return os.TempDir()
		}
	}
	return "/tmp"
}

func newFile(testName string, t *testing.T) (f *os.File) {
	f, err := ioutil.TempFile(localTmp(), "_Go_"+testName)
	if err != nil {
		t.Fatalf("TempFile %s: %s", testName, err)
	}
	return
}

func newDir(testName string, t *testing.T) (name string) {
	name, err := ioutil.TempDir(localTmp(), "_Go_"+testName)
	if err != nil {
		t.Fatalf("TempDir %s: %s", testName, err)
	}
	return
}

var sfdir = sysdir.name
var sfname = sysdir.files[0]

func TestStat(t *testing.T) {
	path := sfdir + "/" + sfname
	dir, err := Stat(path)
	if err != nil {
		t.Fatal("stat failed:", err)
	}
	if !equal(sfname, dir.Name()) {
		t.Error("name should be ", sfname, "; is", dir.Name())
	}
	filesize := size(path, t)
	if dir.Size() != filesize {
		t.Error("size should be", filesize, "; is", dir.Size())
	}
}

func TestFstat(t *testing.T) {
	path := sfdir + "/" + sfname
	file, err1 := Open(path)
	if err1 != nil {
		t.Fatal("open failed:", err1)
	}
	defer file.Close()
	dir, err2 := file.Stat()
	if err2 != nil {
		t.Fatal("fstat failed:", err2)
	}
	if !equal(sfname, dir.Name()) {
		t.Error("name should be ", sfname, "; is", dir.Name())
	}
	filesize := size(path, t)
	if dir.Size() != filesize {
		t.Error("size should be", filesize, "; is", dir.Size())
	}
}

func TestLstat(t *testing.T) {
	path := sfdir + "/" + sfname
	dir, err := Lstat(path)
	if err != nil {
		t.Fatal("lstat failed:", err)
	}
	if !equal(sfname, dir.Name()) {
		t.Error("name should be ", sfname, "; is", dir.Name())
	}
	filesize := size(path, t)
	if dir.Size() != filesize {
		t.Error("size should be", filesize, "; is", dir.Size())
	}
}

// Read with length 0 should not return EOF.
func TestRead0(t *testing.T) {
	path := sfdir + "/" + sfname
	f, err := Open(path)
	if err != nil {
		t.Fatal("open failed:", err)
	}
	defer f.Close()

	b := make([]byte, 0)
	n, err := f.Read(b)
	if n != 0 || err != nil {
		t.Errorf("Read(0) = %d, %v, want 0, nil", n, err)
	}
	b = make([]byte, 100)
	n, err = f.Read(b)
	if n <= 0 || err != nil {
		t.Errorf("Read(100) = %d, %v, want >0, nil", n, err)
	}
}

func testReaddirnames(dir string, contents []string, t *testing.T) {
	file, err := Open(dir)
	if err != nil {
		t.Fatalf("open %q failed: %v", dir, err)
	}
	defer file.Close()
	s, err2 := file.Readdirnames(-1)
	if err2 != nil {
		t.Fatalf("readdirnames %q failed: %v", dir, err2)
	}
	for _, m := range contents {
		found := false
		for _, n := range s {
			if n == "." || n == ".." {
				t.Errorf("got %s in directory", n)
			}
			if equal(m, n) {
				if found {
					t.Error("present twice:", m)
				}
				found = true
			}
		}
		if !found {
			t.Error("could not find", m)
		}
	}
}

func testReaddir(dir string, contents []string, t *testing.T) {
	file, err := Open(dir)
	if err != nil {
		t.Fatalf("open %q failed: %v", dir, err)
	}
	defer file.Close()
	s, err2 := file.Readdir(-1)
	if err2 != nil {
		t.Fatalf("readdir %q failed: %v", dir, err2)
	}
	for _, m := range contents {
		found := false
		for _, n := range s {
			if equal(m, n.Name()) {
				if found {
					t.Error("present twice:", m)
				}
				found = true
			}
		}
		if !found {
			t.Error("could not find", m)
		}
	}
}

func TestReaddirnames(t *testing.T) {
	// CEV: Changed dir "." => "testdata"
	testReaddirnames("testdata", dot, t)
	testReaddirnames(sysdir.name, sysdir.files, t)
}

func TestReaddir(t *testing.T) {
	// CEV: Changed dir "." => "testdata"
	testReaddir("testdata", dot, t)
	testReaddir(sysdir.name, sysdir.files, t)
}

// Read the directory one entry at a time.
func smallReaddirnames(file *os.File, length int, t *testing.T) []string {
	names := make([]string, length)
	count := 0
	for {
		d, err := file.Readdirnames(1)
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatalf("readdirnames %q failed: %v", file.Name(), err)
		}
		if len(d) == 0 {
			t.Fatalf("readdirnames %q returned empty slice and no error", file.Name())
		}
		names[count] = d[0]
		count++
	}
	return names[0:count]
}

// Check that reading a directory one entry at a time gives the same result
// as reading it all at once.
func TestReaddirnamesOneAtATime(t *testing.T) {
	// big directory that doesn't change often.
	dir := "/usr/bin"
	switch runtime.GOOS {
	case "android":
		dir = "/system/bin"
	case "darwin":
		switch runtime.GOARCH {
		case "arm", "arm64":
			wd, err := os.Getwd()
			if err != nil {
				t.Fatal(err)
			}
			dir = wd
		}
	case "plan9":
		dir = "/bin"
	case "windows":
		dir = os.Getenv("SystemRoot") + "\\system32"
	}
	file, err := Open(dir)
	if err != nil {
		t.Fatalf("open %q failed: %v", dir, err)
	}
	defer file.Close()
	all, err1 := file.Readdirnames(-1)
	if err1 != nil {
		t.Fatalf("readdirnames %q failed: %v", dir, err1)
	}
	file1, err2 := Open(dir)
	if err2 != nil {
		t.Fatalf("open %q failed: %v", dir, err2)
	}
	defer file1.Close()
	small := smallReaddirnames(file1, len(all)+100, t) // +100 in case we screw up
	if len(small) < len(all) {
		t.Fatalf("len(small) is %d, less than %d", len(small), len(all))
	}
	for i, n := range all {
		if small[i] != n {
			t.Errorf("small read %q mismatch: %v", small[i], n)
		}
	}
}

func TestReaddirNValues(t *testing.T) {
	if testing.Short() {
		t.Skip("test.short; skipping")
	}
	dir, err := ioutil.TempDir("", "")
	if err != nil {
		t.Fatalf("TempDir: %v", err)
	}
	defer RemoveAll(dir)
	for i := 1; i <= 105; i++ {
		f, err := Create(filepath.Join(dir, fmt.Sprintf("%d", i)))
		if err != nil {
			t.Fatalf("Create: %v", err)
		}
		f.Write([]byte(strings.Repeat("X", i)))
		f.Close()
	}

	var d *os.File
	openDir := func() {
		var err error
		d, err = Open(dir)
		if err != nil {
			t.Fatalf("Open directory: %v", err)
		}
	}

	readDirExpect := func(n, want int, wantErr error) {
		fi, err := d.Readdir(n)
		if err != wantErr {
			t.Fatalf("Readdir of %d got error %v, want %v", n, err, wantErr)
		}
		if g, e := len(fi), want; g != e {
			t.Errorf("Readdir of %d got %d files, want %d", n, g, e)
		}
	}

	readDirNamesExpect := func(n, want int, wantErr error) {
		fi, err := d.Readdirnames(n)
		if err != wantErr {
			t.Fatalf("Readdirnames of %d got error %v, want %v", n, err, wantErr)
		}
		if g, e := len(fi), want; g != e {
			t.Errorf("Readdirnames of %d got %d files, want %d", n, g, e)
		}
	}

	for _, fn := range []func(int, int, error){readDirExpect, readDirNamesExpect} {
		// Test the slurp case
		openDir()
		fn(0, 105, nil)
		fn(0, 0, nil)
		d.Close()

		// Slurp with -1 instead
		openDir()
		fn(-1, 105, nil)
		fn(-2, 0, nil)
		fn(0, 0, nil)
		d.Close()

		// Test the bounded case
		openDir()
		fn(1, 1, nil)
		fn(2, 2, nil)
		fn(105, 102, nil) // and tests buffer >100 case
		fn(3, 0, io.EOF)
		d.Close()
	}
}

// Readdir on a regular file should fail.
func TestReaddirOfFile(t *testing.T) {
	f, err := ioutil.TempFile("", "_Go_ReaddirOfFile")
	if err != nil {
		t.Fatal(err)
	}
	defer Remove(f.Name())
	f.Write([]byte("foo"))
	f.Close()
	reg, err := Open(f.Name())
	if err != nil {
		t.Fatal(err)
	}
	defer reg.Close()

	names, err := reg.Readdirnames(-1)
	if err == nil {
		t.Error("Readdirnames succeeded; want non-nil error")
	}
	if len(names) > 0 {
		t.Errorf("unexpected dir names in regular file: %q", names)
	}
}

func TestHardLink(t *testing.T) {
	if !supportsSymlinks {
		t.Skip("Hard links are not supported on the current volume")
	}
	if runtime.GOOS == "plan9" {
		t.Skip("skipping on plan9, hardlinks not supported")
	}
	defer chtmpdir(t)()
	from, to := "hardlinktestfrom", "hardlinktestto"
	Remove(from) // Just in case.
	file, err := Create(to)
	if err != nil {
		t.Fatalf("open %q failed: %v", to, err)
	}
	defer Remove(to)
	if err = file.Close(); err != nil {
		t.Errorf("close %q failed: %v", to, err)
	}
	err = Link(to, from)
	if err != nil {
		t.Fatalf("link %q, %q failed: %v", to, from, err)
	}

	none := "hardlinktestnone"
	err = Link(none, none)
	// Check the returned error is well-formed.
	if lerr, ok := err.(*os.LinkError); !ok || lerr.Error() == "" {
		t.Errorf("link %q, %q failed to return a valid error", none, none)
	}

	defer Remove(from)
	tostat, err := Stat(to)
	if err != nil {
		t.Fatalf("stat %q failed: %v", to, err)
	}
	fromstat, err := Stat(from)
	if err != nil {
		t.Fatalf("stat %q failed: %v", from, err)
	}
	if !os.SameFile(tostat, fromstat) {
		t.Errorf("link %q, %q did not create hard link", to, from)
	}
}

// chtmpdir changes the working directory to a new temporary directory and
// provides a cleanup function. Used when PWD is read-only.
func chtmpdir(t *testing.T) func() {
	if runtime.GOOS != "darwin" || (runtime.GOARCH != "arm" && runtime.GOARCH != "arm64") {
		return func() {} // only needed on darwin/arm{,64}
	}
	oldwd, err := os.Getwd()
	if err != nil {
		t.Fatalf("chtmpdir: %v", err)
	}
	d, err := ioutil.TempDir("", "test")
	if err != nil {
		t.Fatalf("chtmpdir: %v", err)
	}
	if err := Chdir(d); err != nil {
		t.Fatalf("chtmpdir: %v", err)
	}
	return func() {
		if err := Chdir(oldwd); err != nil {
			t.Fatalf("chtmpdir: %v", err)
		}
		RemoveAll(d)
	}
}

func TestSymlink(t *testing.T) {
	switch runtime.GOOS {
	case "android", "nacl", "plan9":
		t.Skipf("skipping on %s", runtime.GOOS)
	case "windows":
		if !supportsSymlinks {
			t.Skip("Symlinks are not supported on the current volume")
		}
	}
	defer chtmpdir(t)()
	from, to := "symlinktestfrom", "symlinktestto"
	Remove(from) // Just in case.
	file, err := Create(to)
	if err != nil {
		t.Fatalf("open %q failed: %v", to, err)
	}
	defer Remove(to)
	if err = file.Close(); err != nil {
		t.Errorf("close %q failed: %v", to, err)
	}
	err = Symlink(to, from)
	if err != nil {
		t.Fatalf("symlink %q, %q failed: %v", to, from, err)
	}
	defer Remove(from)
	tostat, err := Lstat(to)
	if err != nil {
		t.Fatalf("stat %q failed: %v", to, err)
	}
	if tostat.Mode()&os.ModeSymlink != 0 {
		t.Fatalf("stat %q claims to have found a symlink", to)
	}
	fromstat, err := Stat(from)
	if err != nil {
		t.Fatalf("stat %q failed: %v", from, err)
	}
	if !os.SameFile(tostat, fromstat) {
		t.Errorf("symlink %q, %q did not create symlink", to, from)
	}
	fromstat, err = Lstat(from)
	if err != nil {
		t.Fatalf("lstat %q failed: %v", from, err)
	}
	if fromstat.Mode()&os.ModeSymlink == 0 {
		t.Fatalf("symlink %q, %q did not create symlink", to, from)
	}
	fromstat, err = Stat(from)
	if err != nil {
		t.Fatalf("stat %q failed: %v", from, err)
	}
	if fromstat.Mode()&os.ModeSymlink != 0 {
		t.Fatalf("stat %q did not follow symlink", from)
	}
	s, err := Readlink(from)
	if err != nil {
		t.Fatalf("readlink %q failed: %v", from, err)
	}
	if s != to {
		t.Fatalf("after symlink %q != %q", s, to)
	}
	file, err = Open(from)
	if err != nil {
		t.Fatalf("open %q failed: %v", from, err)
	}
	file.Close()
}

func TestLongSymlink(t *testing.T) {
	switch runtime.GOOS {
	case "plan9", "nacl":
		t.Skipf("skipping on %s", runtime.GOOS)
	case "windows":
		if !supportsSymlinks {
			t.Skip("Symlinks are not supported on the current volume")
		}
	}
	defer chtmpdir(t)()
	s := "0123456789abcdef"
	// Long, but not too long: a common limit is 255.
	s = s + s + s + s + s + s + s + s + s + s + s + s + s + s + s
	from := "longsymlinktestfrom"
	Remove(from) // Just in case.
	err := Symlink(s, from)
	if err != nil {
		t.Fatalf("symlink %q, %q failed: %v", s, from, err)
	}
	defer Remove(from)
	r, err := Readlink(from)
	if err != nil {
		t.Fatalf("readlink %q failed: %v", from, err)
	}
	if runtime.GOOS == "windows" {
		r = filepath.Base(r)
	}
	if r != s {
		t.Fatalf("after symlink %q != %q", r, s)
	}
}

func TestRename(t *testing.T) {
	defer chtmpdir(t)()
	from, to := "renamefrom", "renameto"
	// Ensure we are not testing the overwrite case here.
	Remove(from)
	Remove(to)

	file, err := Create(from)
	if err != nil {
		t.Fatalf("open %q failed: %v", from, err)
	}
	if err = file.Close(); err != nil {
		t.Errorf("close %q failed: %v", from, err)
	}
	err = Rename(from, to)
	if err != nil {
		t.Fatalf("rename %q, %q failed: %v", to, from, err)
	}
	defer Remove(to)
	_, err = Stat(to)
	if err != nil {
		t.Errorf("stat %q failed: %v", to, err)
	}
}

func TestRenameOverwriteDest(t *testing.T) {
	if runtime.GOOS == "plan9" {
		t.Skip("skipping on plan9")
	}
	defer chtmpdir(t)()
	from, to := "renamefrom", "renameto"
	// Just in case.
	Remove(from)
	Remove(to)

	toData := []byte("to")
	fromData := []byte("from")

	err := ioutil.WriteFile(to, toData, 0777)
	if err != nil {
		t.Fatalf("write file %q failed: %v", to, err)
	}

	err = ioutil.WriteFile(from, fromData, 0777)
	if err != nil {
		t.Fatalf("write file %q failed: %v", from, err)
	}
	err = Rename(from, to)
	if err != nil {
		t.Fatalf("rename %q, %q failed: %v", to, from, err)
	}
	defer Remove(to)

	_, err = Stat(from)
	if err == nil {
		t.Errorf("from file %q still exists", from)
	}
	if err != nil && !os.IsNotExist(err) {
		t.Fatalf("stat from: %v", err)
	}
	toFi, err := Stat(to)
	if err != nil {
		t.Fatalf("stat %q failed: %v", to, err)
	}
	if toFi.Size() != int64(len(fromData)) {
		t.Errorf(`"to" size = %d; want %d (old "from" size)`, toFi.Size(), len(fromData))
	}
}

func TestRenameFailed(t *testing.T) {
	defer chtmpdir(t)()
	from, to := "renamefrom", "renameto"
	// Ensure we are not testing the overwrite case here.
	Remove(from)
	Remove(to)

	err := Rename(from, to)
	switch err := err.(type) {
	case *os.LinkError:
		if err.Op != "rename" {
			t.Errorf("rename %q, %q: err.Op: want %q, got %q", from, to, "rename", err.Op)
		}
		if err.Old != from {
			t.Errorf("rename %q, %q: err.Old: want %q, got %q", from, to, from, err.Old)
		}
		if err.New != to {
			t.Errorf("rename %q, %q: err.New: want %q, got %q", from, to, to, err.New)
		}
	case nil:
		t.Errorf("rename %q, %q: expected error, got nil", from, to)

		// cleanup whatever was placed in "renameto"
		Remove(to)
	default:
		t.Errorf("rename %q, %q: expected %T, got %T %v", from, to, new(os.LinkError), err, err)
	}
}

func exec(t *testing.T, dir, cmd string, args []string, expect string) {
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatalf("Pipe: %v", err)
	}
	defer r.Close()
	attr := &os.ProcAttr{Dir: dir, Files: []*os.File{nil, w, os.Stderr}}
	p, err := os.StartProcess(cmd, args, attr)
	if err != nil {
		t.Fatalf("StartProcess: %v", err)
	}
	w.Close()

	var b bytes.Buffer
	io.Copy(&b, r)
	output := b.String()

	fi1, _ := Stat(strings.TrimSpace(output))
	fi2, _ := Stat(expect)
	if !os.SameFile(fi1, fi2) {
		t.Errorf("exec %q returned %q wanted %q",
			strings.Join(append([]string{cmd}, args...), " "), output, expect)
	}
	p.Wait()
}

func checkMode(t *testing.T, path string, mode os.FileMode) {
	dir, err := Stat(path)
	if err != nil {
		t.Fatalf("Stat %q (looking for mode %#o): %s", path, mode, err)
	}
	if dir.Mode()&0777 != mode {
		t.Errorf("Stat %q: mode %#o want %#o", path, dir.Mode(), mode)
	}
}

func TestChmod(t *testing.T) {
	// Chmod is not supported under windows.
	if runtime.GOOS == "windows" {
		return
	}
	f := newFile("TestChmod", t)
	defer Remove(f.Name())
	defer f.Close()

	if err := Chmod(f.Name(), 0456); err != nil {
		t.Fatalf("chmod %s 0456: %s", f.Name(), err)
	}
	checkMode(t, f.Name(), 0456)

	if err := f.Chmod(0123); err != nil {
		t.Fatalf("chmod %s 0123: %s", f.Name(), err)
	}
	checkMode(t, f.Name(), 0123)
}

func checkSize(t *testing.T, f *os.File, size int64) {
	dir, err := f.Stat()
	if err != nil {
		t.Fatalf("Stat %q (looking for size %d): %s", f.Name(), size, err)
	}
	if dir.Size() != size {
		t.Errorf("Stat %q: size %d want %d", f.Name(), dir.Size(), size)
	}
}

func TestFTruncate(t *testing.T) {
	f := newFile("TestFTruncate", t)
	defer Remove(f.Name())
	defer f.Close()

	checkSize(t, f, 0)
	f.Write([]byte("hello, world\n"))
	checkSize(t, f, 13)
	f.Truncate(10)
	checkSize(t, f, 10)
	f.Truncate(1024)
	checkSize(t, f, 1024)
	f.Truncate(0)
	checkSize(t, f, 0)
	_, err := f.Write([]byte("surprise!"))
	if err == nil {
		checkSize(t, f, 13+9) // wrote at offset past where hello, world was.
	}
}

func TestTruncate(t *testing.T) {
	f := newFile("TestTruncate", t)
	defer Remove(f.Name())
	defer f.Close()

	checkSize(t, f, 0)
	f.Write([]byte("hello, world\n"))
	checkSize(t, f, 13)
	os.Truncate(f.Name(), 10)
	checkSize(t, f, 10)
	os.Truncate(f.Name(), 1024)
	checkSize(t, f, 1024)
	os.Truncate(f.Name(), 0)
	checkSize(t, f, 0)
	_, err := f.Write([]byte("surprise!"))
	if err == nil {
		checkSize(t, f, 13+9) // wrote at offset past where hello, world was.
	}
}

func TestChdirAndGetwd(t *testing.T) {
	// TODO(brainman): file.Chdir() is not implemented on windows.
	if runtime.GOOS == "windows" {
		return
	}
	fd, err := Open(".")
	if err != nil {
		t.Fatalf("Open .: %s", err)
	}
	// These are chosen carefully not to be symlinks on a Mac
	// (unlike, say, /var, /etc), except /tmp, which we handle below.
	dirs := []string{"/", "/usr/bin", "/tmp"}
	// /usr/bin does not usually exist on Plan 9 or Android.
	switch runtime.GOOS {
	case "android":
		dirs = []string{"/", "/system/bin"}
	case "plan9":
		dirs = []string{"/", "/usr"}
	case "darwin":
		switch runtime.GOARCH {
		case "arm", "arm64":
			d1, err := ioutil.TempDir("", "d1")
			if err != nil {
				t.Fatalf("TempDir: %v", err)
			}
			d2, err := ioutil.TempDir("", "d2")
			if err != nil {
				t.Fatalf("TempDir: %v", err)
			}
			dirs = []string{d1, d2}
		}
	}
	oldwd := os.Getenv("PWD")
	for mode := 0; mode < 2; mode++ {
		for _, d := range dirs {
			if mode == 0 {
				err = Chdir(d)
			} else {
				fd1, err := Open(d)
				if err != nil {
					t.Errorf("Open %s: %s", d, err)
					continue
				}
				err = fd1.Chdir()
				fd1.Close()
			}
			if d == "/tmp" {
				os.Setenv("PWD", "/tmp")
			}
			pwd, err1 := os.Getwd()
			os.Setenv("PWD", oldwd)
			err2 := fd.Chdir()
			if err2 != nil {
				// We changed the current directory and cannot go back.
				// Don't let the tests continue; they'll scribble
				// all over some other directory.
				fmt.Fprintf(os.Stderr, "fchdir back to dot failed: %s\n", err2)
				os.Exit(1)
			}
			if err != nil {
				fd.Close()
				t.Fatalf("Chdir %s: %s", d, err)
			}
			if err1 != nil {
				fd.Close()
				t.Fatalf("Getwd in %s: %s", d, err1)
			}
			if pwd != d {
				fd.Close()
				t.Fatalf("Getwd returned %q want %q", pwd, d)
			}
		}
	}
	fd.Close()
}

// Test that Chdir+Getwd is program-wide.
func TestProgWideChdir(t *testing.T) {
	const N = 10
	c := make(chan bool)
	cpwd := make(chan string)
	for i := 0; i < N; i++ {
		go func(i int) {
			// Lock half the goroutines in their own operating system
			// thread to exercise more scheduler possibilities.
			if i%2 == 1 {
				// On Plan 9, after calling LockOSThread, the goroutines
				// run on different processes which don't share the working
				// directory. This used to be an issue because Go expects
				// the working directory to be program-wide.
				// See issue 9428.
				runtime.LockOSThread()
			}
			<-c
			pwd, err := os.Getwd()
			if err != nil {
				t.Errorf("Getwd on goroutine %d: %v", i, err)
				return
			}
			cpwd <- pwd
		}(i)
	}
	oldwd, err := os.Getwd()
	if err != nil {
		t.Fatalf("Getwd: %v", err)
	}
	d, err := ioutil.TempDir("", "test")
	if err != nil {
		t.Fatalf("TempDir: %v", err)
	}
	defer func() {
		if err := Chdir(oldwd); err != nil {
			t.Fatalf("Chdir: %v", err)
		}
		RemoveAll(d)
	}()
	if err := Chdir(d); err != nil {
		t.Fatalf("Chdir: %v", err)
	}
	// OS X sets TMPDIR to a symbolic link.
	// So we resolve our working directory again before the test.
	d, err = os.Getwd()
	if err != nil {
		t.Fatalf("Getwd: %v", err)
	}
	close(c)
	for i := 0; i < N; i++ {
		pwd := <-cpwd
		if pwd != d {
			t.Errorf("Getwd returned %q; want %q", pwd, d)
		}
	}
}

func TestSeek(t *testing.T) {
	f := newFile("TestSeek", t)
	defer Remove(f.Name())
	defer f.Close()

	const data = "hello, world\n"
	io.WriteString(f, data)

	type test struct {
		in     int64
		whence int
		out    int64
	}
	var tests = []test{
		{0, 1, int64(len(data))},
		{0, 0, 0},
		{5, 0, 5},
		{0, 2, int64(len(data))},
		{0, 0, 0},
		{-1, 2, int64(len(data)) - 1},
		{1 << 33, 0, 1 << 33},
		{1 << 33, 2, 1<<33 + int64(len(data))},
	}
	for i, tt := range tests {
		off, err := f.Seek(tt.in, tt.whence)
		if off != tt.out || err != nil {
			if e, ok := err.(*os.PathError); ok && e.Err == syscall.EINVAL && tt.out > 1<<32 {
				// Reiserfs rejects the big seeks.
				// https://golang.org/issue/91
				break
			}
			t.Errorf("#%d: Seek(%v, %v) = %v, %v want %v, nil", i, tt.in, tt.whence, off, err, tt.out)
		}
	}
}

type openErrorTest struct {
	path  string
	mode  int
	error error
}

var openErrorTests = []openErrorTest{
	{
		sfdir + "/no-such-file",
		os.O_RDONLY,
		syscall.ENOENT,
	},
	{
		sfdir,
		os.O_WRONLY,
		syscall.EISDIR,
	},
	{
		sfdir + "/" + sfname + "/no-such-file",
		os.O_WRONLY,
		syscall.ENOTDIR,
	},
}

func TestOpenError(t *testing.T) {
	for _, tt := range openErrorTests {
		f, err := OpenFile(tt.path, tt.mode, 0)
		if err == nil {
			t.Errorf("Open(%q, %d) succeeded", tt.path, tt.mode)
			f.Close()
			continue
		}
		perr, ok := err.(*os.PathError)
		if !ok {
			t.Errorf("Open(%q, %d) returns error of %T type; want *PathError", tt.path, tt.mode, err)
		}
		if perr.Err != tt.error {
			if runtime.GOOS == "plan9" {
				syscallErrStr := perr.Err.Error()
				expectedErrStr := strings.Replace(tt.error.Error(), "file ", "", 1)
				if !strings.HasSuffix(syscallErrStr, expectedErrStr) {
					// Some Plan 9 file servers incorrectly return
					// EACCES rather than EISDIR when a directory is
					// opened for write.
					if tt.error == syscall.EISDIR && strings.HasSuffix(syscallErrStr, syscall.EACCES.Error()) {
						continue
					}
					t.Errorf("Open(%q, %d) = _, %q; want suffix %q", tt.path, tt.mode, syscallErrStr, expectedErrStr)
				}
				continue
			}
			if runtime.GOOS == "dragonfly" {
				// DragonFly incorrectly returns EACCES rather
				// EISDIR when a directory is opened for write.
				if tt.error == syscall.EISDIR && perr.Err == syscall.EACCES {
					continue
				}
			}
			t.Errorf("Open(%q, %d) = _, %q; want %q", tt.path, tt.mode, perr.Err.Error(), tt.error.Error())
		}
	}
}

func TestOpenNoName(t *testing.T) {
	f, err := Open("")
	if err == nil {
		t.Fatal(`Open("") succeeded`)
		f.Close()
	}
}

func TestReadAt(t *testing.T) {
	f := newFile("TestReadAt", t)
	defer Remove(f.Name())
	defer f.Close()

	const data = "hello, world\n"
	io.WriteString(f, data)

	b := make([]byte, 5)
	n, err := f.ReadAt(b, 7)
	if err != nil || n != len(b) {
		t.Fatalf("ReadAt 7: %d, %v", n, err)
	}
	if string(b) != "world" {
		t.Fatalf("ReadAt 7: have %q want %q", string(b), "world")
	}
}

// Verify that ReadAt doesn't affect seek offset.
// In the Plan 9 kernel, there used to be a bug in the implementation of
// the pread syscall, where the channel offset was erroneously updated after
// calling pread on a file.
func TestReadAtOffset(t *testing.T) {
	f := newFile("TestReadAtOffset", t)
	defer Remove(f.Name())
	defer f.Close()

	const data = "hello, world\n"
	io.WriteString(f, data)

	f.Seek(0, 0)
	b := make([]byte, 5)

	n, err := f.ReadAt(b, 7)
	if err != nil || n != len(b) {
		t.Fatalf("ReadAt 7: %d, %v", n, err)
	}
	if string(b) != "world" {
		t.Fatalf("ReadAt 7: have %q want %q", string(b), "world")
	}

	n, err = f.Read(b)
	if err != nil || n != len(b) {
		t.Fatalf("Read: %d, %v", n, err)
	}
	if string(b) != "hello" {
		t.Fatalf("Read: have %q want %q", string(b), "hello")
	}
}

func TestWriteAt(t *testing.T) {
	f := newFile("TestWriteAt", t)
	defer Remove(f.Name())
	defer f.Close()

	const data = "hello, world\n"
	io.WriteString(f, data)

	n, err := f.WriteAt([]byte("WORLD"), 7)
	if err != nil || n != 5 {
		t.Fatalf("WriteAt 7: %d, %v", n, err)
	}

	b, err := ioutil.ReadFile(f.Name())
	if err != nil {
		t.Fatalf("ReadFile %s: %v", f.Name(), err)
	}
	if string(b) != "hello, WORLD\n" {
		t.Fatalf("after write: have %q want %q", string(b), "hello, WORLD\n")
	}
}

func writeFile(t *testing.T, fname string, flag int, text string) string {
	f, err := OpenFile(fname, flag, 0666)
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	n, err := io.WriteString(f, text)
	if err != nil {
		t.Fatalf("WriteString: %d, %v", n, err)
	}
	f.Close()
	data, err := ioutil.ReadFile(fname)
	if err != nil {
		t.Fatalf("ReadFile: %v", err)
	}
	return string(data)
}

func TestAppend(t *testing.T) {
	defer chtmpdir(t)()
	const f = "append.txt"
	defer Remove(f)
	s := writeFile(t, f, os.O_CREATE|os.O_TRUNC|os.O_RDWR, "new")
	if s != "new" {
		t.Fatalf("writeFile: have %q want %q", s, "new")
	}
	s = writeFile(t, f, os.O_APPEND|os.O_RDWR, "|append")
	if s != "new|append" {
		t.Fatalf("writeFile: have %q want %q", s, "new|append")
	}
	s = writeFile(t, f, os.O_CREATE|os.O_APPEND|os.O_RDWR, "|append")
	if s != "new|append|append" {
		t.Fatalf("writeFile: have %q want %q", s, "new|append|append")
	}
	err := Remove(f)
	if err != nil {
		t.Fatalf("Remove: %v", err)
	}
	s = writeFile(t, f, os.O_CREATE|os.O_APPEND|os.O_RDWR, "new&append")
	if s != "new&append" {
		t.Fatalf("writeFile: after append have %q want %q", s, "new&append")
	}
	s = writeFile(t, f, os.O_CREATE|os.O_RDWR, "old")
	if s != "old&append" {
		t.Fatalf("writeFile: after create have %q want %q", s, "old&append")
	}
	s = writeFile(t, f, os.O_CREATE|os.O_TRUNC|os.O_RDWR, "new")
	if s != "new" {
		t.Fatalf("writeFile: after truncate have %q want %q", s, "new")
	}
}

func TestStatDirWithTrailingSlash(t *testing.T) {
	// Create new temporary directory and arrange to clean it up.
	path, err := ioutil.TempDir("", "/_TestStatDirWithSlash_")
	if err != nil {
		t.Fatalf("TempDir: %s", err)
	}
	defer RemoveAll(path)

	// Stat of path should succeed.
	_, err = Stat(path)
	if err != nil {
		t.Fatalf("stat %s failed: %s", path, err)
	}

	// Stat of path+"/" should succeed too.
	path += "/"
	_, err = Stat(path)
	if err != nil {
		t.Fatalf("stat %s failed: %s", path, err)
	}
}

func TestNilProcessStateString(t *testing.T) {
	var ps *os.ProcessState
	s := ps.String()
	if s != "<nil>" {
		t.Errorf("(*ProcessState)(nil).String() = %q, want %q", s, "<nil>")
	}
}

func TestSameFile(t *testing.T) {
	defer chtmpdir(t)()
	fa, err := Create("a")
	if err != nil {
		t.Fatalf("Create(a): %v", err)
	}
	defer Remove(fa.Name())
	fa.Close()
	fb, err := Create("b")
	if err != nil {
		t.Fatalf("Create(b): %v", err)
	}
	defer Remove(fb.Name())
	fb.Close()

	ia1, err := Stat("a")
	if err != nil {
		t.Fatalf("Stat(a): %v", err)
	}
	ia2, err := Stat("a")
	if err != nil {
		t.Fatalf("Stat(a): %v", err)
	}
	if !os.SameFile(ia1, ia2) {
		t.Errorf("files should be same")
	}

	ib, err := Stat("b")
	if err != nil {
		t.Fatalf("Stat(b): %v", err)
	}
	if os.SameFile(ia1, ib) {
		t.Errorf("files should be different")
	}
}

func TestDevNullFile(t *testing.T) {
	f, err := Open(os.DevNull)
	if err != nil {
		t.Fatalf("Open(%s): %v", os.DevNull, err)
	}
	defer f.Close()
	fi, err := f.Stat()
	if err != nil {
		t.Fatalf("Stat(%s): %v", os.DevNull, err)
	}
	name := filepath.Base(os.DevNull)
	if fi.Name() != name {
		t.Fatalf("wrong file name have %v want %v", fi.Name(), name)
	}
	if fi.Size() != 0 {
		t.Fatalf("wrong file size have %d want 0", fi.Size())
	}
}

var testLargeWrite = flag.Bool("large_write", false, "run TestLargeWriteToConsole test that floods console with output")

func TestLargeWriteToConsole(t *testing.T) {
	if !*testLargeWrite {
		t.Skip("skipping console-flooding test; enable with -large_write")
	}
	b := make([]byte, 32000)
	for i := range b {
		b[i] = '.'
	}
	b[len(b)-1] = '\n'
	n, err := os.Stdout.Write(b)
	if err != nil {
		t.Fatalf("Write to os.Stdout failed: %v", err)
	}
	if n != len(b) {
		t.Errorf("Write to os.Stdout should return %d; got %d", len(b), n)
	}
	n, err = os.Stderr.Write(b)
	if err != nil {
		t.Fatalf("Write to os.Stderr failed: %v", err)
	}
	if n != len(b) {
		t.Errorf("Write to os.Stderr should return %d; got %d", len(b), n)
	}
}

func TestStatDirModeExec(t *testing.T) {
	const mode = 0111

	path, err := ioutil.TempDir("", "go-build")
	if err != nil {
		t.Fatalf("Failed to create temp directory: %v", err)
	}
	defer RemoveAll(path)

	if err := Chmod(path, 0777); err != nil {
		t.Fatalf("Chmod %q 0777: %v", path, err)
	}

	dir, err := Stat(path)
	if err != nil {
		t.Fatalf("Stat %q (looking for mode %#o): %s", path, mode, err)
	}
	if dir.Mode()&mode != mode {
		t.Errorf("Stat %q: mode %#o want %#o", path, dir.Mode()&mode, mode)
	}
}

func TestReadAtEOF(t *testing.T) {
	f := newFile("TestReadAtEOF", t)
	defer Remove(f.Name())
	defer f.Close()

	_, err := f.ReadAt(make([]byte, 10), 0)
	switch err {
	case io.EOF:
		// all good
	case nil:
		t.Fatalf("ReadAt succeeded")
	default:
		t.Fatalf("ReadAt failed: %s", err)
	}
}

var nilFileMethodTests = []struct {
	name string
	f    func(*os.File) error
}{
	{"Chdir", func(f *os.File) error { return f.Chdir() }},
	{"Close", func(f *os.File) error { return f.Close() }},
	{"Chmod", func(f *os.File) error { return f.Chmod(0) }},
	{"Chown", func(f *os.File) error { return f.Chown(0, 0) }},
	{"Read", func(f *os.File) error { _, err := f.Read(make([]byte, 0)); return err }},
	{"ReadAt", func(f *os.File) error { _, err := f.ReadAt(make([]byte, 0), 0); return err }},
	{"Readdir", func(f *os.File) error { _, err := f.Readdir(1); return err }},
	{"Readdirnames", func(f *os.File) error { _, err := f.Readdirnames(1); return err }},
	{"Seek", func(f *os.File) error { _, err := f.Seek(0, 0); return err }},
	{"Stat", func(f *os.File) error { _, err := f.Stat(); return err }},
	{"Sync", func(f *os.File) error { return f.Sync() }},
	{"Truncate", func(f *os.File) error { return f.Truncate(0) }},
	{"Write", func(f *os.File) error { _, err := f.Write(make([]byte, 0)); return err }},
	{"WriteAt", func(f *os.File) error { _, err := f.WriteAt(make([]byte, 0), 0); return err }},
	{"WriteString", func(f *os.File) error { _, err := f.WriteString(""); return err }},
}

// Test that all File methods give ErrInvalid if the receiver is nil.
func TestNilFileMethods(t *testing.T) {
	for _, tt := range nilFileMethodTests {
		var file *os.File
		got := tt.f(file)
		if got != os.ErrInvalid {
			t.Errorf("%v should fail when f is nil; got %v", tt.name, got)
		}
	}
}

func mkdirTree(t *testing.T, root string, level, max int) {
	if level >= max {
		return
	}
	level++
	for i := 'a'; i < 'c'; i++ {
		dir := filepath.Join(root, string(i))
		if err := Mkdir(dir, 0700); err != nil {
			t.Fatal(err)
		}
		mkdirTree(t, dir, level, max)
	}
}

// Test that simultaneous RemoveAll do not report an error.
// As long as it gets removed, we should be happy.
func TestRemoveAllRace(t *testing.T) {
	if runtime.GOOS == "windows" {
		// Windows has very strict rules about things like
		// removing directories while someone else has
		// them open. The racing doesn't work out nicely
		// like it does on Unix.
		t.Skip("skipping on windows")
	}

	n := runtime.GOMAXPROCS(16)
	defer runtime.GOMAXPROCS(n)
	root, err := ioutil.TempDir("", "issue")
	if err != nil {
		t.Fatal(err)
	}
	mkdirTree(t, root, 1, 6)
	hold := make(chan struct{})
	var wg sync.WaitGroup
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-hold
			err := RemoveAll(root)
			if err != nil {
				t.Errorf("unexpected error: %T, %q", err, err)
			}
		}()
	}
	close(hold) // let workers race to remove root
	wg.Wait()
}
