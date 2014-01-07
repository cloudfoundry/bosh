package system

import "os"

type FileSystem interface {
	HomeDir(username string) (path string, err error)

	MkdirAll(path string, perm os.FileMode) (err error)
	RemoveAll(fileOrDir string)

	Chown(path, username string) (err error)
	Chmod(path string, perm os.FileMode) (err error)

	Open(path string) (file *os.File, err error)
	WriteToFile(path, content string) (written bool, err error)
	ReadFile(path string) (content string, err error)
	FileExists(path string) bool
	Rename(oldPath, newPath string) (err error)

	// After Symlink file at newPath will be pointing to file at oldPath.
	// Symlink call will remove file at newPath if one exists
	// to make newPath a symlink to the file at oldPath.
	Symlink(oldPath, newPath string) (err error)

	// Copies contents of one directory into another directory.
	// Both directories need to exist before copy can succeed.
	// Overwrites files in the dstPath but does not remove
	// files from dstPath that are not found in srcPath (= adds/overwrites).
	CopyDirEntries(srcPath, dstPath string) (err error)
	CopyFile(srcPath, dstPath string) (err error)

	// Returns *unique* temporary file/dir with a custom prefix
	TempFile(prefix string) (file *os.File, err error)
	TempDir(prefix string) (path string, err error)

	Glob(pattern string) (matches []string, err error)
}
