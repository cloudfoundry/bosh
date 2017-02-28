// The below code uses portions of the Go standard library.
// The full license can be found in fs.go.
//
// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package fs

import (
	"io"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"time"
	"unicode"
)

// https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx#maxpath
//
//   When using an API to create a directory, the specified path cannot be so
//   long that you cannot append an 8.3 file name (that is, the directory name
//   cannot exceed MAX_PATH minus 12).
//
//   MAX_PATH = 260
//
const MAX_PATH = 248 // 260 - 12

func absPath(path string) (string, error) {
	if filepath.IsAbs(path) {
		return filepath.Clean(path), nil
	}
	return filepath.Abs(filepath.Clean(path))
}

func winPath(path string) (string, error) {
	if len(path) == 0 || (len(path) >= 2 && path[:2] == `\\`) {
		return path, nil
	}
	p, err := absPath(path)
	if err != nil {
		return "", err
	}
	if len(p) >= MAX_PATH {
		return `\\?\` + strings.TrimRightFunc(p, unicode.IsSpace), nil
	}
	return path, nil
}

func newPathError(op, path string, err error) error {
	return &os.PathError{
		Op:   "fs: " + op,
		Path: path,
		Err:  err,
	}
}

func newLinkError(op, oldname, newname string, err error) error {
	return &os.LinkError{
		Op:  "fs: " + op,
		Old: oldname,
		New: newname,
		Err: err,
	}
}

func chdir(dir string) error {
	p, err := winPath(dir)
	if err != nil {
		return newPathError("chdir", dir, err)
	}
	return os.Chdir(p)
}

func chmod(name string, mode os.FileMode) error {
	p, err := winPath(name)
	if err != nil {
		return newPathError("chmod", name, err)
	}
	return os.Chmod(p, mode)
}

func chown(name string, uid, gid int) error {
	p, err := winPath(name)
	if err != nil {
		return newPathError("chown", name, err)
	}
	return os.Chown(p, uid, gid)
}

func chtimes(name string, atime time.Time, mtime time.Time) error {
	p, err := winPath(name)
	if err != nil {
		return newPathError("chtimes", name, err)
	}
	return os.Chtimes(p, atime, mtime)
}

func lchown(name string, uid, gid int) error {
	p, err := winPath(name)
	if err != nil {
		return newPathError("lchown", name, err)
	}
	return os.Lchown(p, uid, gid)
}

func link(oldname, newname string) error {
	op, err := winPath(oldname)
	if err != nil {
		return newLinkError("link", oldname, newname, err)
	}
	np, err := winPath(newname)
	if err != nil {
		return newLinkError("link", oldname, newname, err)
	}
	return os.Link(op, np)
}

func mkdir(name string, perm os.FileMode) error {
	p, err := winPath(name)
	if err != nil {
		return newPathError("mkdir", name, err)
	}
	return os.Mkdir(p, perm)
}

func mkdirall(path string, perm os.FileMode) error {
	p, err := winPath(path)
	if err != nil {
		return err
	}
	return os.MkdirAll(p, perm)
}

func readlink(name string) (string, error) {
	p, err := winPath(name)
	if err != nil {
		return "", newPathError("readlink", name, err)
	}
	return os.Readlink(p)
}

func remove(name string) error {
	p, err := winPath(name)
	if err != nil {
		return newPathError("remove", name, err)
	}
	return os.Remove(p)
}

func removeall(name string) error {
	path, err := winPath(name)
	if err != nil {
		return newPathError("remove", path, err)
	}
	// Simple case: if Remove works, we're done.
	err = os.Remove(path)
	if err == nil || os.IsNotExist(err) {
		return nil
	}

	// Otherwise, is this a directory we need to recurse into?
	dir, serr := Lstat(path)
	if serr != nil {
		if serr, ok := serr.(*os.PathError); ok && (os.IsNotExist(serr.Err) || serr.Err == syscall.ENOTDIR) {
			return nil
		}
		return serr
	}
	if !dir.IsDir() {
		// Not a directory; return the error from Remove.
		return err
	}

	// Directory.
	fd, err := Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			// Race. It was deleted between the Lstat and Open.
			// Return nil per RemoveAll's docs.
			return nil
		}
		return err
	}

	// Remove contents & return first error.
	err = nil
	for {
		names, err1 := fd.Readdirnames(100)
		for _, name := range names {
			err1 := RemoveAll(path + string(os.PathSeparator) + name)
			if err == nil {
				err = err1
			}
		}
		if err1 == io.EOF {
			break
		}
		// If Readdirnames returned an error, use it.
		if err == nil {
			err = err1
		}
		if len(names) == 0 {
			break
		}
	}

	// Close directory, because windows won't remove opened directory.
	fd.Close()

	// Remove directory.
	err1 := Remove(path)
	if err1 == nil || os.IsNotExist(err1) {
		return nil
	}
	if err == nil {
		err = err1
	}
	return err
}

func rename(oldpath, newpath string) error {
	op, err := winPath(oldpath)
	if err != nil {
		return newLinkError("rename", oldpath, newpath, err)
	}
	np, err := winPath(newpath)
	if err != nil {
		return newLinkError("rename", oldpath, newpath, err)
	}
	return os.Rename(op, np)
}

func symlink(oldname, newname string) error {
	op, err := winPath(oldname)
	if err != nil {
		return newLinkError("symlink", oldname, newname, err)
	}
	np, err := winPath(newname)
	if err != nil {
		return newLinkError("symlink", oldname, newname, err)
	}
	return os.Symlink(op, np)
}

func create(name string) (*os.File, error) {
	p, err := winPath(name)
	if err != nil {
		return nil, newPathError("create", name, err)
	}
	return os.Create(p)
}

func newfile(fd uintptr, name string) *os.File {
	p, err := winPath(name)
	if err != nil {
		return os.NewFile(fd, name)
	}
	return os.NewFile(fd, p)
}

func open(name string) (*os.File, error) {
	p, err := winPath(name)
	if err != nil {
		return nil, newPathError("open", name, err)
	}
	return os.Open(p)
}

func openfile(name string, flag int, perm os.FileMode) (*os.File, error) {
	p, err := winPath(name)
	if err != nil {
		return nil, newPathError("openfile", name, err)
	}
	return os.OpenFile(p, flag, perm)
}

func lstat(name string) (os.FileInfo, error) {
	p, err := winPath(name)
	if err != nil {
		return nil, newPathError("lstat", name, err)
	}
	return os.Lstat(p)
}

func stat(name string) (os.FileInfo, error) {
	p, err := winPath(name)
	if err != nil {
		return nil, newPathError("stat", name, err)
	}
	return os.Stat(p)
}
