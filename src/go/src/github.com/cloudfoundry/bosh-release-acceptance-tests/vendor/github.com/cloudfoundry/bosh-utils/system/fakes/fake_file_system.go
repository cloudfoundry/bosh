package fakes

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	gopath "path"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"syscall"

	gouuid "github.com/nu7hatch/gouuid"

	bosherr "github.com/cloudfoundry/bosh-utils/errors"
	boshsys "github.com/cloudfoundry/bosh-utils/system"
)

type FakeFileType string

type removeAllFn func(path string) error

type globFn func(pattern string) ([]string, error)

const (
	FakeFileTypeFile    FakeFileType = "file"
	FakeFileTypeSymlink FakeFileType = "symlink"
	FakeFileTypeDir     FakeFileType = "dir"
)

type FakeFileSystem struct {
	fileRegistry *FakeFileStatsRegistry
	filesLock    sync.Mutex

	HomeDirUsername string
	HomeDirHomePath string

	ExpandPathPath     string
	ExpandPathExpanded string
	ExpandPathErr      error

	openFileRegistry *FakeFileRegistry
	OpenFileErr      error

	ReadFileError       error
	readFileErrorByPath map[string]error

	WriteFileError  error
	WriteFileErrors map[string]error
	SymlinkError    error

	MkdirAllError       error
	mkdirAllErrorByPath map[string]error

	ChangeTempRootErr error

	ChownErr error
	ChmodErr error

	CopyFileError     error
	CopyFileCallCount int

	CopyDirError error

	RenameError    error
	RenameOldPaths []string
	RenameNewPaths []string

	RemoveAllStub removeAllFn

	ReadAndFollowLinkError error

	TempFileError           error
	TempFileErrorsByPrefix  map[string]error
	ReturnTempFile          boshsys.File
	ReturnTempFiles         []boshsys.File
	ReturnTempFilesByPrefix map[string]boshsys.File

	TempDirDir   string
	TempDirDirs  []string
	TempDirError error

	GlobErr  error
	GlobStub globFn
	GlobErrs map[string]error
	globsMap map[string][][]string

	WalkErr error

	TempRootPath   string
	strictTempRoot bool
}

type FakeFileStats struct {
	FileType FakeFileType

	FileMode os.FileMode
	Flags    int
	Username string

	Open bool

	SymlinkTarget string

	Content []byte
}

func (stats FakeFileStats) StringContents() string {
	return string(stats.Content)
}

type FakeFileInfo struct {
	os.FileInfo
	file FakeFile
}

func (fi FakeFileInfo) Mode() os.FileMode {
	return fi.file.Stats.FileMode
}

func (fi FakeFileInfo) Size() int64 {
	return int64(len(fi.file.Contents))
}

func (fi FakeFileInfo) IsDir() bool {
	return fi.file.Stats.FileType == FakeFileTypeDir
}

type FakeFile struct {
	path string
	fs   *FakeFileSystem

	Stats *FakeFileStats

	WriteErr error
	Contents []byte

	ReadErr   error
	ReadAtErr error
	readIndex int64

	CloseErr error

	StatErr error
}

func NewFakeFile(path string, fs *FakeFileSystem) *FakeFile {
	fakeFile := &FakeFile{
		path: path,
		fs:   fs,
	}
	me := fs.fileRegistry.Get(path)
	if me != nil {
		fakeFile.Contents = me.Content
		fakeFile.Stats = me
		fakeFile.Stats.Open = true
	}
	return fakeFile
}

func (f *FakeFile) Name() string {
	return f.path
}

func (f *FakeFile) Write(contents []byte) (int, error) {
	if f.WriteErr != nil {
		return 0, f.WriteErr
	}

	f.fs.filesLock.Lock()
	defer f.fs.filesLock.Unlock()

	stats := f.fs.getOrCreateFile(f.path)
	stats.Content = contents

	f.Contents = contents
	return len(contents), nil
}

func (f *FakeFile) Read(b []byte) (int, error) {
	if f.readIndex >= int64(len(f.Contents)) {
		return 0, io.EOF
	}
	copy(b, f.Contents)
	f.readIndex = int64(len(f.Contents))
	return len(f.Contents), f.ReadErr
}

func (f *FakeFile) ReadAt(b []byte, offset int64) (int, error) {
	copy(b, f.Contents[offset:])
	return len(f.Contents[offset:]), f.ReadAtErr
}

func (f *FakeFile) WriteAt(b []byte, offset int64) (int, error) {
	return len(b), nil
}

func (f *FakeFile) Seek(int64, int) (int64, error) {
	return 0, nil
}

func (f *FakeFile) Close() error {
	if f.Stats != nil {
		f.Stats.Open = false
	}
	return f.CloseErr
}

func (f FakeFile) Stat() (os.FileInfo, error) {
	return FakeFileInfo{file: f}, f.StatErr
}

func NewFakeFileSystem() *FakeFileSystem {
	return &FakeFileSystem{
		fileRegistry:           NewFakeFileStatsRegistry(),
		openFileRegistry:       NewFakeFileRegistry(),
		GlobErrs:               map[string]error{},
		globsMap:               map[string][][]string{},
		readFileErrorByPath:    map[string]error{},
		mkdirAllErrorByPath:    map[string]error{},
		WriteFileErrors:        map[string]error{},
		TempFileErrorsByPrefix: map[string]error{},
	}
}

func (fs *FakeFileSystem) GetFileTestStat(path string) *FakeFileStats {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	return fs.fileRegistry.Get(path)
}

func (fs *FakeFileSystem) HomeDir(username string) (string, error) {
	fs.HomeDirUsername = username
	return fs.HomeDirHomePath, nil
}

func (fs *FakeFileSystem) ExpandPath(path string) (string, error) {
	fs.ExpandPathPath = path
	if fs.ExpandPathExpanded == "" {
		return fs.ExpandPathPath, fs.ExpandPathErr
	}

	return fs.ExpandPathExpanded, fs.ExpandPathErr
}

func (fs *FakeFileSystem) RegisterMkdirAllError(path string, err error) {
	path = gopath.Join(path)
	if _, ok := fs.mkdirAllErrorByPath[path]; ok {
		panic(fmt.Sprintf("MkdirAll error is already set for path: %s", path))
	}
	fs.mkdirAllErrorByPath[path] = err
}

func (fs *FakeFileSystem) MkdirAll(path string, perm os.FileMode) error {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	if fs.MkdirAllError != nil {
		return fs.MkdirAllError
	}

	path = gopath.Join(path)

	if fs.mkdirAllErrorByPath[path] != nil {
		return fs.mkdirAllErrorByPath[path]
	}

	stats := fs.getOrCreateFile(path)
	stats.FileMode = perm
	stats.FileType = FakeFileTypeDir
	fs.fileRegistry.Register(path, stats)

	return nil
}

func (fs *FakeFileSystem) RegisterOpenFile(path string, file *FakeFile) {
	path = gopath.Join(path)
	fs.openFileRegistry.Register(path, file)
}

func (fs *FakeFileSystem) FindFileStats(path string) (*FakeFileStats, error) {
	if stats := fs.fileRegistry.Get(path); stats != nil {
		return stats, nil
	}
	return nil, fmt.Errorf("Path does not exist: %s", path)
}

func (fs *FakeFileSystem) OpenFile(path string, flag int, perm os.FileMode) (boshsys.File, error) {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	if fs.OpenFileErr != nil {
		return nil, fs.OpenFileErr
	}

	// Make sure to record a reference for FileExist, etc. to work
	stats := fs.getOrCreateFile(path)
	stats.FileMode = perm
	stats.Flags = flag
	stats.FileType = FakeFileTypeFile

	openFile := fs.openFileRegistry.Get(path)
	if openFile != nil {
		return openFile, nil
	}
	file := NewFakeFile(path, fs)

	fs.RegisterOpenFile(path, file)
	return file, nil
}

func (fs *FakeFileSystem) Stat(path string) (os.FileInfo, error) {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	openFile := fs.openFileRegistry.Get(path)
	if openFile != nil {
		return openFile.Stat()
	}

	stats := fs.fileRegistry.Get(path)
	if stats == nil {
		panic(fmt.Sprintf("Unexpected Stat call for path '%s' that does not exist", path))
	}

	if stats.FileType == FakeFileTypeSymlink {
		targetStats := fs.fileRegistry.Get(stats.SymlinkTarget)
		if targetStats == nil {
			return nil, fmt.Errorf("stat: %s: no such file or directory", path)
		}

		stats = targetStats
	}

	return NewFakeFile(path, fs).Stat()
}

func (fs *FakeFileSystem) Readlink(path string) (string, error) {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	stats := fs.fileRegistry.Get(path)
	if stats == nil {
		return "", errors.New(fmt.Sprintf("path '%s' does not exist", path))
	}

	if stats.FileType != FakeFileTypeSymlink {
		return "", errors.New(fmt.Sprintf("cannot readlink of non-symlink"))
	}

	return stats.SymlinkTarget, nil
}

func (fs *FakeFileSystem) Lstat(path string) (os.FileInfo, error) {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	openFile := fs.openFileRegistry.Get(path)
	if openFile != nil {
		return openFile.Stat()
	}

	stats := fs.fileRegistry.Get(path)
	if stats == nil {
		panic(fmt.Sprintf("Unexpected Stat call for path '%s' that does not exist", path))
	}

	return NewFakeFile(path, fs).Stat()
}

func (fs *FakeFileSystem) Chown(path, username string) error {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	// check early to avoid requiring file presence
	if fs.ChownErr != nil {
		return fs.ChownErr
	}

	stats := fs.fileRegistry.Get(path)
	if stats == nil {
		return fmt.Errorf("Path does not exist: %s", path)
	}

	stats.Username = username
	return nil
}

func (fs *FakeFileSystem) Chmod(path string, perm os.FileMode) error {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	// check early to avoid requiring file presence
	if fs.ChmodErr != nil {
		return fs.ChmodErr
	}

	stats := fs.fileRegistry.Get(path)
	if stats == nil {
		return fmt.Errorf("Path does not exist: %s", path)
	}

	stats.FileMode = perm
	return nil
}

func (fs *FakeFileSystem) WriteFileString(path, content string) error {
	return fs.WriteFile(path, []byte(content))
}

func (fs *FakeFileSystem) WriteFile(path string, content []byte) error {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	err := fs.WriteFileError
	if err != nil {
		return err
	}

	err = fs.WriteFileErrors[path]
	if err != nil {
		return err
	}

	path = fs.fileRegistry.UnifiedPath(path)
	parent := gopath.Dir(path)
	if parent != "." {
		fs.writeDir(parent)
	}

	stats := fs.getOrCreateFile(path)
	stats.FileType = FakeFileTypeFile
	stats.Content = content
	return nil
}

func (fs *FakeFileSystem) writeDir(path string) error {
	parent := gopath.Dir(path)

	grandparent := gopath.Dir(parent)
	if grandparent != parent {
		fs.writeDir(parent)
	}

	stats := fs.getOrCreateFile(path)
	stats.FileType = FakeFileTypeDir
	return nil
}

func (fs *FakeFileSystem) ConvergeFileContents(path string, content []byte) (bool, error) {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	if fs.WriteFileError != nil {
		return false, fs.WriteFileError
	}

	err := fs.WriteFileErrors[path]
	if err != nil {
		return false, err
	}

	stats := fs.getOrCreateFile(path)
	stats.FileType = FakeFileTypeFile

	if bytes.Compare(stats.Content, content) != 0 {
		stats.Content = content
		return true, nil
	}

	return false, nil
}

func (fs *FakeFileSystem) ReadFileString(path string) (string, error) {
	bytes, err := fs.ReadFile(path)
	if err != nil {
		return "", err
	}

	return string(bytes), nil
}

func (fs *FakeFileSystem) RegisterReadFileError(path string, err error) {
	if _, ok := fs.readFileErrorByPath[path]; ok {
		panic(fmt.Sprintf("ReadFile error is already set for path: %s", path))
	}
	fs.readFileErrorByPath[path] = err
}

func (fs *FakeFileSystem) ReadFile(path string) ([]byte, error) {
	stats := fs.GetFileTestStat(path)
	if stats != nil {
		if fs.ReadFileError != nil {
			return nil, fs.ReadFileError
		}

		if fs.readFileErrorByPath[path] != nil {
			return nil, fs.readFileErrorByPath[path]
		}

		return stats.Content, nil
	}

	return nil, bosherr.ComplexError{
		Err: bosherr.Error("Not found"),
		Cause: &os.PathError{
			Op:   "open",
			Path: path,
			Err:  syscall.ENOENT,
		},
	}
}

func (fs *FakeFileSystem) FileExists(path string) bool {
	return fs.GetFileTestStat(path) != nil
}

func (fs *FakeFileSystem) Rename(oldPath, newPath string) error {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	if fs.RenameError != nil {
		return fs.RenameError
	}

	oldPath = fs.fileRegistry.UnifiedPath(oldPath)
	newPath = fs.fileRegistry.UnifiedPath(newPath)

	parentDir := gopath.Dir(newPath)
	if parentDir != "." && fs.fileRegistry.Get(parentDir) == nil {
		return errors.New("Parent directory does not exist")
	}

	stats := fs.fileRegistry.Get(oldPath)
	if stats == nil {
		return errors.New("Old path did not exist")
	}

	fs.RenameOldPaths = append(fs.RenameOldPaths, oldPath)
	fs.RenameNewPaths = append(fs.RenameNewPaths, newPath)

	newStats := fs.getOrCreateFile(newPath)
	newStats.Content = stats.Content
	newStats.FileMode = stats.FileMode
	newStats.FileType = stats.FileType
	newStats.Flags = stats.Flags

	// Ignore error from RemoveAll
	fs.removeAll(oldPath)

	return nil
}

func (fs *FakeFileSystem) Symlink(oldPath, newPath string) (err error) {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	if fs.SymlinkError == nil {
		stats := fs.getOrCreateFile(newPath)
		stats.FileMode |= os.ModeSymlink
		stats.FileType = FakeFileTypeSymlink
		stats.SymlinkTarget = fs.fileRegistry.UnifiedPath(oldPath)
		return
	}

	err = fs.SymlinkError
	return
}

func (fs *FakeFileSystem) ReadAndFollowLink(symlinkPath string) (string, error) {
	if fs.ReadAndFollowLinkError != nil {
		return "", fs.ReadAndFollowLinkError
	}

	symlinkPath = gopath.Join(symlinkPath)

	stat := fs.GetFileTestStat(symlinkPath)
	if stat != nil {
		targetStat := fs.GetFileTestStat(stat.SymlinkTarget)

		if targetStat == nil {
			return stat.SymlinkTarget, os.ErrNotExist
		} else if FakeFileTypeSymlink == targetStat.FileType {
			return fs.ReadAndFollowLink(stat.SymlinkTarget)
		}

		return stat.SymlinkTarget, nil
	}

	return "", os.ErrNotExist
}

func (fs *FakeFileSystem) CopyFile(srcPath, dstPath string) error {
	fs.CopyFileCallCount++
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	if fs.CopyFileError != nil {
		return fs.CopyFileError
	}

	srcFile := fs.fileRegistry.Get(srcPath)
	if srcFile == nil {
		return errors.New(fmt.Sprintf("%s doesn't exist", srcPath))
	}

	fs.fileRegistry.Register(dstPath, srcFile)
	return nil
}

func (fs *FakeFileSystem) CopyDir(srcPath, dstPath string) error {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	if fs.CopyDirError != nil {
		return fs.CopyDirError
	}

	srcPath = fs.fileRegistry.UnifiedPath(srcPath) + "/"
	dstPath = fs.fileRegistry.UnifiedPath(dstPath)

	for filePath, fileStats := range fs.fileRegistry.GetAll() {
		if strings.HasPrefix(filePath, srcPath) {
			dstPath := gopath.Join(dstPath, filePath[len(srcPath)-1:])
			fs.fileRegistry.Register(dstPath, fileStats)
		}
	}

	return nil
}

func (fs *FakeFileSystem) ChangeTempRoot(tempRootPath string) error {
	if fs.ChangeTempRootErr != nil {
		return fs.ChangeTempRootErr
	}
	fs.TempRootPath = tempRootPath
	return nil
}

func (fs *FakeFileSystem) EnableStrictTempRootBehavior() {
	fs.strictTempRoot = true
}

func (fs *FakeFileSystem) TempFile(prefix string) (file boshsys.File, err error) {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	if fs.TempFileError != nil {
		return nil, fs.TempFileError
	}

	if fs.TempFileErrorsByPrefix[prefix] != nil {
		return nil, fs.TempFileErrorsByPrefix[prefix]
	}

	if fs.strictTempRoot && fs.TempRootPath == "" {
		return nil, errors.New("Temp file was requested without having set a temp root")
	}

	if fs.ReturnTempFilesByPrefix != nil {
		file = fs.ReturnTempFilesByPrefix[prefix]
	} else if fs.ReturnTempFile != nil {
		file = fs.ReturnTempFile
	} else if len(fs.ReturnTempFiles) != 0 {
		file = fs.ReturnTempFiles[0]
		fs.ReturnTempFiles = fs.ReturnTempFiles[1:]
	} else {
		file, err = os.Open(os.DevNull)
		if err != nil {
			err = bosherr.WrapError(err, fmt.Sprintf("Opening %s", os.DevNull))
			return
		}
	}

	// Make sure to record a reference for FileExist, etc. to work
	stats := fs.getOrCreateFile(file.Name())
	stats.FileType = FakeFileTypeFile
	return
}

func (fs *FakeFileSystem) TempDir(prefix string) (string, error) {
	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	if fs.TempDirError != nil {
		return "", fs.TempDirError
	}

	if fs.strictTempRoot && fs.TempRootPath == "" {
		return "", errors.New("Temp file was requested without having set a temp root")
	}

	var path string
	if len(fs.TempDirDir) > 0 {
		path = fs.TempDirDir
	} else if fs.TempDirDirs != nil {
		if len(fs.TempDirDirs) == 0 {
			return "", errors.New("Failed to create new temp dir: TempDirDirs is empty")
		}
		path = fs.TempDirDirs[0]
		fs.TempDirDirs = fs.TempDirDirs[1:]
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

func (fs *FakeFileSystem) RemoveAll(path string) error {
	if path == "" {
		panic("RemoveAll requires path")
	}

	if fs.RemoveAllStub != nil {
		err := fs.RemoveAllStub(path)
		if err != nil {
			return err
		}
	}

	fs.filesLock.Lock()
	defer fs.filesLock.Unlock()

	path = fs.fileRegistry.UnifiedPath(path)
	return fs.removeAll(path)
}

func (fs *FakeFileSystem) removeAll(path string) error {
	fileInfo := fs.fileRegistry.Get(path)
	if fileInfo != nil {
		fs.fileRegistry.Remove(path)
		if fileInfo.FileType != FakeFileTypeDir {
			return nil
		}
	}

	// path must be a dir
	path = path + "/"

	filesToRemove := []string{}
	for name := range fs.fileRegistry.GetAll() {
		if strings.HasPrefix(name, path) {
			filesToRemove = append(filesToRemove, name)
		}
	}
	for _, name := range filesToRemove {
		fs.fileRegistry.Remove(name)
	}

	return nil
}

func (fs *FakeFileSystem) Glob(pattern string) (matches []string, err error) {
	if fs.GlobStub != nil {
		_, err = fs.GlobStub(pattern)
		if err != nil {
			return nil, err
		}
	}

	remainingMatches, found := fs.globsMap[pattern]
	if found {
		matches = remainingMatches[0]
		if len(remainingMatches) > 1 {
			fs.globsMap[pattern] = remainingMatches[1:]
		}
	} else {
		matches = []string{}
	}
	if err, ok := fs.GlobErrs[pattern]; ok {
		return matches, err
	}
	return matches, fs.GlobErr
}

func (fs *FakeFileSystem) RecursiveGlob(pattern string) (matches []string, err error) {
	return fs.Glob(pattern)
}

func (fs *FakeFileSystem) Walk(root string, walkFunc filepath.WalkFunc) error {
	if fs.WalkErr != nil {
		return walkFunc("", nil, fs.WalkErr)
	}

	var paths []string
	for path := range fs.fileRegistry.GetAll() {
		paths = append(paths, path)
	}
	sort.Strings(paths)

	root = gopath.Join(root) + "/"
	for _, path := range paths {
		fileStats := fs.fileRegistry.Get(path)
		if strings.HasPrefix(path, root) {
			fakeFile := NewFakeFile(path, fs)
			fakeFile.Stats = fileStats
			fileInfo, _ := fakeFile.Stat()
			err := walkFunc(path, fileInfo, nil)
			if err != nil {
				return err
			}
		}
	}

	return nil
}

func (fs *FakeFileSystem) SetGlob(pattern string, matches ...[]string) {
	fs.globsMap[pattern] = matches
}

func (fs *FakeFileSystem) getOrCreateFile(path string) *FakeFileStats {
	stats := fs.fileRegistry.Get(path)
	if stats == nil {
		stats = new(FakeFileStats)
		fs.fileRegistry.Register(path, stats)
	}
	return stats
}

type FakeFileStatsRegistry struct {
	files map[string]*FakeFileStats
}

func NewFakeFileStatsRegistry() *FakeFileStatsRegistry {
	return &FakeFileStatsRegistry{
		files: map[string]*FakeFileStats{},
	}
}

func (fsr *FakeFileStatsRegistry) Register(path string, stats *FakeFileStats) {
	fsr.files[fsr.UnifiedPath(path)] = stats
}

func (fsr *FakeFileStatsRegistry) Get(path string) *FakeFileStats {
	return fsr.files[fsr.UnifiedPath(path)]
}

func (fsr *FakeFileStatsRegistry) GetAll() map[string]*FakeFileStats {
	return fsr.files
}

func (fsr *FakeFileStatsRegistry) Remove(path string) {
	delete(fsr.files, fsr.UnifiedPath(path))
}

func (fsr *FakeFileStatsRegistry) UnifiedPath(path string) string {
	path = strings.TrimPrefix(path, filepath.VolumeName(path))
	return filepath.ToSlash(gopath.Join(path))
}

type FakeFileRegistry struct {
	files map[string]*FakeFile
}

func NewFakeFileRegistry() *FakeFileRegistry {
	return &FakeFileRegistry{
		files: map[string]*FakeFile{},
	}
}

func (ffr *FakeFileRegistry) Register(path string, file *FakeFile) {
	ffr.files[ffr.UnifiedPath(path)] = file
}

func (ffr *FakeFileRegistry) Get(path string) *FakeFile {
	return ffr.files[ffr.UnifiedPath(path)]
}

func (ffr *FakeFileRegistry) UnifiedPath(path string) string {
	path = strings.TrimPrefix(path, filepath.VolumeName(path))
	return filepath.ToSlash(gopath.Join(path))
}
