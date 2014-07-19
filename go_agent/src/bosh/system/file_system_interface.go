package system

import (
	"io"
	"os"
)

type ReadWriteCloseStater interface {
	io.ReadWriteCloser
	ReadAt([]byte, int64) (int, error)
	Stat() (os.FileInfo, error)
}

type FileSystem interface {
	HomeDir(username string) (path string, err error)

	// MkdirAll will not change existing dir permissions
	// if dir exists and has different permissions
	MkdirAll(path string, perm os.FileMode) (err error)
	RemoveAll(fileOrDir string) (err error)

	Chown(path, username string) (err error)
	Chmod(path string, perm os.FileMode) (err error)

	OpenFile(path string, flag int, perm os.FileMode) (ReadWriteCloseStater, error)

	WriteFileString(path, content string) (err error)
	WriteFile(path string, content []byte) (err error)
	ConvergeFileContents(path string, content []byte) (written bool, err error)

	ReadFileString(path string) (content string, err error)
	ReadFile(path string) (content []byte, err error)

	FileExists(path string) bool

	Rename(oldPath, newPath string) (err error)

	// After Symlink file at newPath will be pointing to file at oldPath.
	// Symlink call will remove file at newPath if one exists
	// to make newPath a symlink to the file at oldPath.
	Symlink(oldPath, newPath string) (err error)
	ReadLink(symlinkPath string) (targetPath string, err error)

	CopyFile(srcPath, dstPath string) (err error)

	// Returns *unique* temporary file/dir with a custom prefix
	TempFile(prefix string) (file *os.File, err error)
	TempDir(prefix string) (path string, err error)

	Glob(pattern string) (matches []string, err error)
}
