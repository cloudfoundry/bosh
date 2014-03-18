package fakes

import (
	bosherr "bosh/errors"
	"bytes"
	"errors"
	gouuid "github.com/nu7hatch/gouuid"
	"os"
	"strings"
)

type FakeFileType string

const (
	FakeFileTypeFile    FakeFileType = "file"
	FakeFileTypeSymlink FakeFileType = "symlink"
	FakeFileTypeDir     FakeFileType = "dir"
)

type FakeFileSystem struct {
	Files map[string]*FakeFileStats

	HomeDirUsername string
	HomeDirHomePath string

	FilesToOpen map[string]*os.File

	WriteToFileError error
	MkdirAllError    error
	SymlinkError     error

	CopyDirEntriesError   error
	CopyDirEntriesSrcPath string
	CopyDirEntriesDstPath string

	CopyFileError error

	RenameError    error
	RenameOldPaths []string
	RenameNewPaths []string

	RemoveAllError error

	TempFileError  error
	ReturnTempFile *os.File

	TempDirDir   string
	TempDirError error

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
		globsMap: make(map[string][][]string),
	}
}

func (fs *FakeFileSystem) GetFileTestStat(path string) (stats *FakeFileStats) {
	stats = fs.Files[path]
	return
}

func (fs *FakeFileSystem) HomeDir(username string) (path string, err error) {
	fs.HomeDirUsername = username
	path = fs.HomeDirHomePath
	return
}

func (fs *FakeFileSystem) MkdirAll(path string, perm os.FileMode) (err error) {
	if fs.MkdirAllError == nil {
		stats := fs.getOrCreateFile(path)
		stats.FileMode = perm
		stats.FileType = FakeFileTypeDir
	}

	err = fs.MkdirAllError
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

func (fs *FakeFileSystem) ReadFile(path string) (content []byte, err error) {
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

func (fs *FakeFileSystem) Rename(oldPath, newPath string) (err error) {
	if fs.RenameError != nil {
		err = fs.RenameError
		return
	}

	stats := fs.GetFileTestStat(oldPath)
	if stats == nil {
		err = errors.New("Old path did not exist")
		return
	}

	fs.RenameOldPaths = append(fs.RenameOldPaths, oldPath)
	fs.RenameNewPaths = append(fs.RenameNewPaths, newPath)

	newStats := fs.getOrCreateFile(newPath)
	newStats.Content = stats.Content
	newStats.FileMode = stats.FileMode
	newStats.FileType = stats.FileType

	fs.RemoveAll(oldPath)

	return
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

func (fs *FakeFileSystem) ReadLink(symlinkPath string) (targetPath string, err error) {
	stat := fs.GetFileTestStat(symlinkPath)
	if stat != nil {
		targetPath = stat.SymlinkTarget
	} else {
		err = os.ErrNotExist
	}

	return
}

func (fs *FakeFileSystem) CopyDirEntries(srcPath, dstPath string) (err error) {
	if fs.CopyDirEntriesError != nil {
		return fs.CopyDirEntriesError
	}

	filesToCopy := []string{}

	for filePath, _ := range fs.Files {
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

	fs.Files[dstPath] = fs.Files[srcPath]
	return
}

func (fs *FakeFileSystem) TempFile(prefix string) (file *os.File, err error) {
	if fs.TempFileError != nil {
		return nil, fs.TempFileError
	}
	if fs.ReturnTempFile != nil {
		return fs.ReturnTempFile, nil
	} else {
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

func (fs *FakeFileSystem) RemoveAll(path string) (err error) {
	if fs.RemoveAllError != nil {
		return fs.RemoveAllError
	}

	filesToRemove := []string{}

	for name, _ := range fs.Files {
		if strings.HasPrefix(name, path) {
			filesToRemove = append(filesToRemove, name)
		}
	}

	for _, name := range filesToRemove {
		delete(fs.Files, name)
	}
	return
}

func (fs *FakeFileSystem) Open(path string) (file *os.File, err error) {
	file = fs.FilesToOpen[path]
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
	return
}

func (fs *FakeFileSystem) SetGlob(pattern string, matches ...[]string) {
	fs.globsMap[pattern] = matches
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
