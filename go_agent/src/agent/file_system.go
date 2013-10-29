package agent

import "os"

type FileSystem interface {
	HomeDir(username string) (homeDir string, err error)
	MkdirAll(path string, perm os.FileMode) (err error)
	Chown(path, username string) (err error)
	Chmod(path string, perm os.FileMode) (err error)
	WriteToFile(path, content string) (err error)
}
