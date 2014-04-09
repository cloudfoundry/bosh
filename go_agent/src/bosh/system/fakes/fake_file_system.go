package fakes

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	gouuid "github.com/nu7hatch/gouuid"

	bosherr "bosh/errors"
)

type FakeFileType string

const (
	FakeFileTypeFile    FakeFileType = "file"
	FakeFileTypeSymlink FakeFileType = "symlink"
	FakeFileTypeDir     FakeFileType = "dir"
)

type FakeFileSystem struct {
	files map[string]*FakeFileStats

	HomeDirUsername string
	HomeDirHomePath string

	ReadFileError    error
	WriteToFileError error
	SymlinkError     error

	MkdirAllError       error
	mkdirAllErrorByPath map[string]error

	ChownErr error
	ChmodErr error

	CopyDirEntriesError   error
	CopyDirEntriesSrcPath string
	CopyDirEntriesDstPath string

	CopyFileError error

	RenameError    error
	RenameOldPaths []string
	RenameNewPaths []string

	RemoveAllError       error
	removeAllErrorByPath map[string]error

	ReadLinkError error

	TempFileError  error
	ReturnTempFile *os.File

	TempDirDir   string
	TempDirError error

	GlobErr  error
	globsMap map[string][][]string
}

type FakeFileStats struct {
	FileMode      os.FileMode
	Username      string
	Content       []byte
	SymlinkTarget string
	FileType      FakeFileType
}

func (stats FakeFileStats) StringContents() string {
	return string(stats.Content)
}

func NewFakeFileSystem() *FakeFileSystem {
	return &FakeFileSystem{
		globsMap:             map[string][][]string{},
		removeAllErrorByPath: map[string]error{},
		mkdirAllErrorByPath:  map[string]error{},
	}
}

func (fs *FakeFileSystem) GetFileTestStat(path string) (stats *FakeFileStats) {
	stats = fs.files[path]
	return
}

func (fs *FakeFileSystem) HomeDir(username string) (path string, err error) {
	fs.HomeDirUsername = username
	path = fs.HomeDirHomePath
	return
}

func (fs *FakeFileSystem) RegisterMkdirAllError(path string, err error) {
	if _, ok := fs.mkdirAllErrorByPath[path]; ok {
		panic(fmt.Sprintf("MkdirAll error is already set for path: %s", path))
	}
	fs.mkdirAllErrorByPath[path] = err
}

func (fs *FakeFileSystem) MkdirAll(path string, perm os.FileMode) error {
	if fs.MkdirAllError != nil {
		return fs.MkdirAllError
	}

	if fs.mkdirAllErrorByPath[path] != nil {
		return fs.mkdirAllErrorByPath[path]
	}

	stats := fs.getOrCreateFile(path)
	stats.FileMode = perm
	stats.FileType = FakeFileTypeDir
	return nil
}

func (fs *FakeFileSystem) Chown(path, username string) error {
	// check early to avoid requiring file presence
	if fs.ChownErr != nil {
		return fs.ChownErr
	}
	stats := fs.GetFileTestStat(path)
	stats.Username = username
	return nil
}

func (fs *FakeFileSystem) Chmod(path string, perm os.FileMode) error {
	// check early to avoid requiring file presence
	if fs.ChmodErr != nil {
		return fs.ChmodErr
	}

	stats := fs.GetFileTestStat(path)
	if stats == nil {
		return fmt.Errorf("Path does not exist: %s", path)
	}

	stats.FileMode = perm
	return nil
}

func (fs *FakeFileSystem) WriteFileString(path, content string) (err error) {
	return fs.WriteFile(path, []byte(content))
}

func (fs *FakeFileSystem) WriteFile(path string, content []byte) (err error) {
	if fs.WriteToFileError != nil {
		err = fs.WriteToFileError
		return
	}

	stats := fs.getOrCreateFile(path)
	stats.FileType = FakeFileTypeFile
	stats.Content = content
	return
}

func (fs *FakeFileSystem) ConvergeFileContents(path string, content []byte) (written bool, err error) {
	if fs.WriteToFileError != nil {
		err = fs.WriteToFileError
		return
	}

	stats := fs.getOrCreateFile(path)
	stats.FileType = FakeFileTypeFile

	if bytes.Compare(stats.Content, content) != 0 {
		stats.Content = content
		written = true
	}
	return
}

func (fs *FakeFileSystem) ReadFileString(path string) (content string, err error) {
	bytes, err := fs.ReadFile(path)
	if err != nil {
		return
	}

	content = string(bytes)
	return
}

func (fs *FakeFileSystem) ReadFile(path string) ([]byte, error) {
	stats := fs.GetFileTestStat(path)
	if stats != nil {
		if fs.ReadFileError != nil {
			return nil, fs.ReadFileError
		}
		return stats.Content, nil
	}
	return nil, errors.New("File not found")
}

func (fs *FakeFileSystem) FileExists(path string) bool {
	return fs.GetFileTestStat(path) != nil
}

func (fs *FakeFileSystem) Rename(oldPath, newPath string) error {
	if fs.RenameError != nil {
		return fs.RenameError
	}

	if fs.GetFileTestStat(filepath.Dir(newPath)) == nil {
		return errors.New("Parent directory does not exist")
	}

	stats := fs.GetFileTestStat(oldPath)
	if stats == nil {
		return errors.New("Old path did not exist")
	}

	fs.RenameOldPaths = append(fs.RenameOldPaths, oldPath)
	fs.RenameNewPaths = append(fs.RenameNewPaths, newPath)

	newStats := fs.getOrCreateFile(newPath)
	newStats.Content = stats.Content
	newStats.FileMode = stats.FileMode
	newStats.FileType = stats.FileType

	// Ignore error from RemoveAll
	fs.RemoveAll(oldPath)

	return nil
}

func (fs *FakeFileSystem) Symlink(oldPath, newPath string) (err error) {
	if fs.SymlinkError == nil {
		stats := fs.getOrCreateFile(newPath)
		stats.FileType = FakeFileTypeSymlink
		stats.SymlinkTarget = oldPath
		return
	}

	err = fs.SymlinkError
	return
}

func (fs *FakeFileSystem) ReadLink(symlinkPath string) (string, error) {
	if fs.ReadLinkError != nil {
		return "", fs.ReadLinkError
	}

	stat := fs.GetFileTestStat(symlinkPath)
	if stat != nil {
		return stat.SymlinkTarget, nil
	}

	return "", os.ErrNotExist
}

func (fs *FakeFileSystem) CopyDirEntries(srcPath, dstPath string) (err error) {
	if fs.CopyDirEntriesError != nil {
		return fs.CopyDirEntriesError
	}

	filesToCopy := []string{}

	for filePath := range fs.Files {
		if strings.HasPrefix(filePath, srcPath) {
			filesToCopy = append(filesToCopy, filePath)
		}
	}

	for _, filePath := range filesToCopy {
		newPath := strings.Replace(filePath, srcPath, dstPath, 1)
		fs.Files[newPath] = fs.Files[filePath]
	}

	return
}

func (fs *FakeFileSystem) CopyFile(srcPath, dstPath string) (err error) {
	if fs.CopyFileError != nil {
		err = fs.CopyFileError
		return
	}

	fs.files[dstPath] = fs.files[srcPath]
	return
}

func (fs *FakeFileSystem) TempFile(prefix string) (file *os.File, err error) {
	if fs.TempFileError != nil {
		return nil, fs.TempFileError
	}

	if fs.ReturnTempFile != nil {
		return fs.ReturnTempFile, nil
	}

	file, err = os.Open("/dev/null")
	if err != nil {
		err = bosherr.WrapError(err, "Opening /dev/null")
		return
	}

	// Make sure to record a reference for FileExist, etc. to work
	stats := fs.getOrCreateFile(file.Name())
	stats.FileType = FakeFileTypeFile
	return
}

func (fs *FakeFileSystem) TempDir(prefix string) (string, error) {
	if fs.TempDirError != nil {
		return "", fs.TempDirError
	}

	var path string
	if len(fs.TempDirDir) > 0 {
		path = fs.TempDirDir
	} else {
		uuid, err := gouuid.NewV4()
		if err != nil {
			return "", err
		}

		path = uuid.String()
	}

	// Make sure to record a reference for FileExist, etc. to work
	stats := fs.getOrCreateFile(path)
	stats.FileType = FakeFileTypeDir

	return path, nil
}

func (fs *FakeFileSystem) RegisterRemoveAllError(path string, err error) {
	if _, ok := fs.removeAllErrorByPath[path]; ok {
		panic(fmt.Sprintf("RemoveAll error is already set for path: %s", path))
	}
	fs.removeAllErrorByPath[path] = err
}

func (fs *FakeFileSystem) RemoveAll(path string) (err error) {
	if fs.RemoveAllError != nil {
		return fs.RemoveAllError
	}

	if fs.removeAllErrorByPath[path] != nil {
		return fs.removeAllErrorByPath[path]
	}

	filesToRemove := []string{}

	for name := range fs.files {
		if strings.HasPrefix(name, path) {
			filesToRemove = append(filesToRemove, name)
		}
	}

	for _, name := range filesToRemove {
		delete(fs.files, name)
	}
	return
}

func (fs *FakeFileSystem) Glob(pattern string) (matches []string, err error) {
	remainingMatches, found := fs.globsMap[pattern]
	if found {
		matches = remainingMatches[0]
		if len(remainingMatches) > 1 {
			fs.globsMap[pattern] = remainingMatches[1:]
		}
	} else {
		matches = []string{}
	}
	return matches, fs.GlobErr
}

func (fs *FakeFileSystem) SetGlob(pattern string, matches ...[]string) {
	fs.globsMap[pattern] = matches
	return
}

func (fs *FakeFileSystem) getOrCreateFile(path string) (stats *FakeFileStats) {
	stats = fs.GetFileTestStat(path)
	if stats == nil {
		if fs.files == nil {
			fs.files = make(map[string]*FakeFileStats)
		}

		stats = new(FakeFileStats)
		fs.files[path] = stats
	}
	return
}
