// +build !windows

package fs

import (
	"os"
	"time"
)

func chdir(dir string) error {
	return os.Chdir(dir)
}

func chmod(name string, mode os.FileMode) error {
	return os.Chmod(name, mode)
}

func chown(name string, uid, gid int) error {
	return os.Chown(name, uid, gid)
}

func chtimes(name string, atime time.Time, mtime time.Time) error {
	return os.Chtimes(name, atime, mtime)
}

func lchown(name string, uid, gid int) error {
	return os.Lchown(name, uid, gid)
}

func link(oldname, newname string) error {
	return os.Link(oldname, newname)
}

func mkdir(name string, perm os.FileMode) error {
	return os.Mkdir(name, perm)
}

func mkdirall(path string, perm os.FileMode) error {
	return os.MkdirAll(path, perm)
}

func readlink(name string) (string, error) {
	return os.Readlink(name)
}

func remove(name string) error {
	return os.Remove(name)
}

func removeall(path string) error {
	return os.RemoveAll(path)
}

func rename(oldpath, newpath string) error {
	return os.Rename(oldpath, newpath)
}

func symlink(oldname, newname string) error {
	return os.Symlink(oldname, newname)
}

func create(name string) (*os.File, error) {
	return os.Create(name)
}

func newfile(fd uintptr, name string) *os.File {
	return os.NewFile(fd, name)
}

func open(name string) (*os.File, error) {
	return os.Open(name)
}

func openfile(name string, flag int, perm os.FileMode) (*os.File, error) {
	return os.OpenFile(name, flag, perm)
}

func lstat(name string) (os.FileInfo, error) {
	return os.Lstat(name)
}

func stat(name string) (os.FileInfo, error) {
	return os.Stat(name)
}
