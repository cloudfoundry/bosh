package system

import "os"

type FileSystem interface {
	HomeDir(username string) (homeDir string, err error)
	MkdirAll(path string, perm os.FileMode) (err error)

	Chown(path, username string) (err error)
	Chmod(path string, perm os.FileMode) (err error)

	WriteToFile(path, content string) (written bool, err error)
	Open(path string) (file *os.File, err error)
	ReadFile(path string) (content string, err error)
	RemoveAll(fileOrDir string)
	FileExists(path string) bool

	// After Symlink file at newPath will be pointing to file at oldPath.
	// Symlink call will remove file at newPath if one exists
	// to make newPath a symlink to the file at oldPath.
	Symlink(oldPath, newPath string) (err error)

	TempDir() (tmpDir string)
}
