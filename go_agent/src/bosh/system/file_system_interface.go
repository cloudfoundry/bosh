package system

import "os"

type FileSystem interface {
	HomeDir(username string) (homeDir string, err error)
	MkdirAll(path string, perm os.FileMode) (err error)
	Chown(path, username string) (err error)
	Chmod(path string, perm os.FileMode) (err error)
	WriteToFile(path, content string) (written bool, err error)
	ReadFile(path string) (content string, err error)
	FileExists(path string) bool
	Symlink(oldPath, newPath string) (err error)
	TempDir() (tmpDir string)
	RemoveAll(fileOrDir string)
	Open(path string) (file *os.File, err error)
}
