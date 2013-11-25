package fakes

import (
	"errors"
	"os"
	"strings"
)

type FakeFileType string

const (
	FakeFileTypeFile    FakeFileType = "file"
	FakeFileTypeSymlink              = "symlink"
	FakeFileTypeDir                  = "dir"
)

type FakeFileSystem struct {
	Files map[string]*FakeFileStats

	HomeDirUsername string
	HomeDirHomeDir  string

	FilesToOpen map[string]*os.File
}

type FakeFileStats struct {
	FileMode      os.FileMode
	Username      string
	Content       string
	SymlinkTarget string
	FileType      FakeFileType
}

func (fs *FakeFileSystem) GetFileTestStat(path string) (stats *FakeFileStats) {
	stats = fs.Files[path]
	return
}

func (fs *FakeFileSystem) HomeDir(username string) (homeDir string, err error) {
	fs.HomeDirUsername = username
	homeDir = fs.HomeDirHomeDir
	return
}

func (fs *FakeFileSystem) MkdirAll(path string, perm os.FileMode) (err error) {
	stats := fs.getOrCreateFile(path)
	stats.FileMode = perm
	stats.FileType = FakeFileTypeDir
	return
}

func (fs *FakeFileSystem) Chown(path, username string) (err error) {
	stats := fs.GetFileTestStat(path)
	stats.Username = username
	return
}

func (fs *FakeFileSystem) Chmod(path string, perm os.FileMode) (err error) {
	stats := fs.GetFileTestStat(path)
	stats.FileMode = perm
	return
}

func (fs *FakeFileSystem) WriteToFile(path, content string) (written bool, err error) {
	stats := fs.getOrCreateFile(path)
	stats.FileType = FakeFileTypeFile

	if stats.Content != content {
		stats.Content = content
		written = true
	}
	return
}

func (fs *FakeFileSystem) ReadFile(path string) (content string, err error) {
	stats := fs.GetFileTestStat(path)
	if stats != nil {
		content = stats.Content
	} else {
		err = errors.New("File not found")
	}
	return
}

func (fs *FakeFileSystem) FileExists(path string) bool {
	return fs.GetFileTestStat(path) != nil
}

func (fs *FakeFileSystem) Symlink(oldPath, newPath string) (err error) {
	stats := fs.getOrCreateFile(newPath)
	stats.FileType = FakeFileTypeSymlink
	stats.SymlinkTarget = oldPath
	return
}

func (fs *FakeFileSystem) TempDir() (tmpDir string) {
	return os.TempDir()
}

func (fs *FakeFileSystem) RemoveAll(fileOrDir string) {
	filesToRemove := []string{}

	for name, _ := range fs.Files {
		if strings.HasPrefix(name, fileOrDir) {
			filesToRemove = append(filesToRemove, name)
		}
	}

	for _, name := range filesToRemove {
		delete(fs.Files, name)
	}
}

func (fs *FakeFileSystem) Open(path string) (file *os.File, err error) {
	file = fs.FilesToOpen[path]
	return
}

func (fs *FakeFileSystem) getOrCreateFile(path string) (stats *FakeFileStats) {
	stats = fs.GetFileTestStat(path)
	if stats == nil {
		if fs.Files == nil {
			fs.Files = make(map[string]*FakeFileStats)
		}

		stats = new(FakeFileStats)
		fs.Files[path] = stats
	}
	return
}
