package system

import (
	"io"
	"os"
	"path/filepath"
)

// File is a subset of os.File
type File interface {
	io.ReadWriteCloser
	ReadAt([]byte, int64) (int, error)
	WriteAt([]byte, int64) (int, error)
	Seek(int64, int) (int64, error)
	Stat() (os.FileInfo, error)
	Name() string
}

type FileSystem interface {
	HomeDir(username string) (path string, err error)
	ExpandPath(path string) (expandedPath string, err error)

	// MkdirAll will not change existing dir permissions
	// if dir exists and has different permissions
	MkdirAll(path string, perm os.FileMode) error
	RemoveAll(fileOrDir string) error

	Chown(path, username string) error
	Chmod(path string, perm os.FileMode) error

	OpenFile(path string, flag int, perm os.FileMode) (File, error)

	WriteFileString(path, content string) error
	WriteFile(path string, content []byte) error
	ConvergeFileContents(path string, content []byte) (written bool, err error)

	ReadFileString(path string) (content string, err error)
	ReadFile(path string) (content []byte, err error)

	FileExists(path string) bool
	Stat(path string) (os.FileInfo, error)
	Lstat(path string) (os.FileInfo, error)

	Rename(oldPath, newPath string) error

	// After Symlink file at newPath will be pointing to file at oldPath.
	// Symlink call will remove file at newPath if one exists
	// to make newPath a symlink to the file at oldPath.
	Symlink(oldPath, newPath string) error

	// deprecated - The fake_file_system version of this method behaves differently
	// 				than the os_file_system.  It doesn't traverse all intermediate directories
	// 				of symlinkPath and only attempts to follow the specific file.
	//              This method used to be called ReadLink(path) (string,error),
	//              which was misleading. This method errors when the target exists,
	//			    unlike the os.Readlink method (lower case l). This method should
	//              probably just go away.
	ReadAndFollowLink(symlinkPath string) (targetPath string, err error)
	Readlink(symlinkPath string) (targetPath string, err error)

	CopyFile(srcPath, dstPath string) error
	CopyDir(srcPath, dstPath string) error

	// Returns *unique* temporary file/dir with a custom prefix
	TempFile(prefix string) (file File, err error)
	TempDir(prefix string) (path string, err error)
	ChangeTempRoot(path string) error

	Glob(pattern string) (matches []string, err error)
	RecursiveGlob(pattern string) (matches []string, err error)
	Walk(root string, walkFunc filepath.WalkFunc) error
}
