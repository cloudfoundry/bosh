package system

import (
	"bytes"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"errors"

	"github.com/bmatcuk/doublestar"
	fsWrapper "github.com/charlievieth/fs"
	bosherr "github.com/cloudfoundry/bosh-utils/errors"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
)

type osFileSystem struct {
	logger           boshlog.Logger
	logTag           string
	tempRoot         string
	requiresTempRoot bool
}

func NewOsFileSystem(logger boshlog.Logger) FileSystem {
	return &osFileSystem{logger: logger, logTag: "File System", requiresTempRoot: false}
}

func NewOsFileSystemWithStrictTempRoot(logger boshlog.Logger) FileSystem {
	return &osFileSystem{logger: logger, logTag: "File System", requiresTempRoot: true}
}

func (fs *osFileSystem) HomeDir(username string) (string, error) {
	fs.logger.Debug(fs.logTag, "Getting HomeDir for %s", username)
	dir, err := fs.homeDir(username)
	if err != nil {
		return "", err
	}
	fs.logger.Debug(fs.logTag, "HomeDir is %s", dir)
	return dir, nil
}

func (fs *osFileSystem) ExpandPath(path string) (string, error) {
	fs.logger.Debug(fs.logTag, "Expanding path for '%s'", path)

	if strings.HasPrefix(path, "~") {
		home, err := fs.currentHomeDir()
		if err != nil {
			return "", bosherr.WrapError(err, "Getting current user home dir")
		}
		path = filepath.Join(home, path[1:])
	}

	path, err := filepath.Abs(path)
	if err != nil {
		return "", bosherr.WrapError(err, "Getting absolute path")
	}

	return path, nil
}

func (fs *osFileSystem) MkdirAll(path string, perm os.FileMode) (err error) {
	fs.logger.Debug(fs.logTag, "Making dir %s with perm %#o", path, perm)
	return fsWrapper.MkdirAll(path, perm)
}

func (fs *osFileSystem) Chown(path, username string) error {
	fs.logger.Debug(fs.logTag, "Chown %s to user %s", path, username)
	return fs.chown(path, username)
}

func (fs *osFileSystem) Chmod(path string, perm os.FileMode) (err error) {
	fs.logger.Debug(fs.logTag, "Chmod %s to %d", path, perm)
	return fsWrapper.Chmod(path, perm)
}

func (fs *osFileSystem) openFile(path string, flag int, perm os.FileMode) (*os.File, error) {
	return fsWrapper.OpenFile(path, flag, perm)
}

func (fs *osFileSystem) OpenFile(path string, flag int, perm os.FileMode) (File, error) {
	return fs.openFile(path, flag, perm)
}

func (fs *osFileSystem) Stat(path string) (os.FileInfo, error) {
	fs.logger.Debug(fs.logTag, "Stat '%s'", path)
	return fsWrapper.Stat(path)
}

func (fs *osFileSystem) Lstat(path string) (os.FileInfo, error) {
	fs.logger.Debug(fs.logTag, "Lstat '%s'", path)
	return fsWrapper.Lstat(path)
}

func (fs *osFileSystem) WriteFileString(path, content string) (err error) {
	return fs.WriteFile(path, []byte(content))
}

func (fs *osFileSystem) WriteFile(path string, content []byte) error {
	fs.logger.Debug(fs.logTag, "Writing %s", path)

	err := fs.MkdirAll(filepath.Dir(path), os.ModePerm)
	if err != nil {
		return bosherr.WrapError(err, "Creating dir to write file")
	}

	file, err := fs.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0666)
	if err != nil {
		return bosherr.WrapErrorf(err, "Creating file %s", path)
	}

	defer file.Close()

	fs.logger.DebugWithDetails(fs.logTag, "Write content", content)

	_, err = file.Write(content)
	if err != nil {
		return bosherr.WrapErrorf(err, "Writing content to file %s", path)
	}

	return nil
}

func (fs *osFileSystem) ConvergeFileContents(path string, content []byte) (bool, error) {

	fi, err := fs.Stat(path)
	if err != nil || fi.Size() != int64(len(content)) {
		return true, fs.WriteFile(path, content)
	}

	file, err := fs.openFile(path, os.O_CREATE|os.O_RDWR, 0666)
	if err != nil {
		return true, bosherr.WrapErrorf(err, "Creating file %s", path)
	}
	defer file.Close()

	src, err := ioutil.ReadAll(file)
	if err != nil {
		return true, bosherr.WrapErrorf(err, "Reading file %s", path)
	}
	if bytes.Equal(src, content) {
		fs.logger.Debug(fs.logTag, "Skipping writing %s because contents are identical", path)
		return false, nil
	}

	fs.logger.Debug(fs.logTag, "File %s will be overwritten", path)

	if _, err := file.Seek(0, 0); err != nil {
		return true, bosherr.WrapErrorf(err, "Seeking file %s", path)
	}
	if err := file.Truncate(int64(len(content))); err != nil {
		return true, bosherr.WrapErrorf(err, "Truncating file %s", path)
	}
	if _, err := file.Write(content); err != nil {
		return true, bosherr.WrapErrorf(err, "Writing content to file %s", path)
	}

	return true, nil
}

func (fs *osFileSystem) ReadFileString(path string) (content string, err error) {
	bytes, err := fs.ReadFile(path)
	if err != nil {
		return
	}

	content = string(bytes)
	return
}

func (fs *osFileSystem) ReadFile(path string) (content []byte, err error) {
	fs.logger.Debug(fs.logTag, "Reading file %s", path)

	file, err := fs.OpenFile(path, os.O_RDONLY, 0)
	if err != nil {
		err = bosherr.WrapErrorf(err, "Opening file %s", path)
		return
	}

	defer file.Close()

	content, err = ioutil.ReadAll(file)
	if err != nil {
		err = bosherr.WrapErrorf(err, "Reading file content %s", path)
		return
	}

	fs.logger.DebugWithDetails(fs.logTag, "Read content", content)
	return
}

func (fs *osFileSystem) FileExists(path string) bool {
	fs.logger.Debug(fs.logTag, "Checking if file exists %s", path)

	_, err := fs.Stat(path)
	if err != nil {
		return !os.IsNotExist(err)
	}
	return true
}

func (fs *osFileSystem) Rename(oldPath, newPath string) (err error) {
	fs.logger.Debug(fs.logTag, "Renaming %s to %s", oldPath, newPath)

	fs.RemoveAll(newPath)
	return fsWrapper.Rename(oldPath, newPath)
}

func (fs *osFileSystem) Symlink(oldPath, newPath string) error {
	fs.logger.Debug(fs.logTag, "Symlinking oldPath %s with newPath %s", oldPath, newPath)

	source, target, err := fs.symlinkPaths(oldPath, newPath)
	if err != nil {
		bosherr.WrapErrorf(err, "Getting absolute paths for target and path links: %s %s", oldPath, newPath)
	}
	if fi, err := fs.Lstat(target); err == nil {
		if fi.Mode()&os.ModeSymlink != 0 {
			// Symlink
			new, err := fs.Readlink(target)
			if err != nil {
				return bosherr.WrapErrorf(err, "Reading link for %s", target)
			}
			if filepath.Clean(source) == filepath.Clean(new) {
				return nil
			}
		}
		if err := fs.RemoveAll(target); err != nil {
			return bosherr.WrapErrorf(err, "Removing new path at %s", target)
		}
	}

	containingDir := filepath.Dir(target)
	if !fs.FileExists(containingDir) {
		fs.MkdirAll(containingDir, os.FileMode(0700))
	}

	return fsWrapper.Symlink(source, target)
}

func (fs *osFileSystem) ReadAndFollowLink(symlinkPath string) (targetPath string, err error) {
	return filepath.EvalSymlinks(symlinkPath)
}

func (fs *osFileSystem) Readlink(symlinkPath string) (targetPath string, err error) {
	return fsWrapper.Readlink(symlinkPath)
}

func (fs *osFileSystem) CopyFile(srcPath, dstPath string) error {
	fs.logger.Debug(fs.logTag, "Copying file '%s' to '%s'", srcPath, dstPath)

	srcFile, err := fs.OpenFile(srcPath, os.O_RDONLY, 0)
	if err != nil {
		return bosherr.WrapError(err, "Opening source path")
	}

	defer srcFile.Close()

	dstFile, err := fs.OpenFile(dstPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0666)
	if err != nil {
		return bosherr.WrapError(err, "Creating destination file")
	}

	defer dstFile.Close()

	_, err = io.Copy(dstFile, srcFile)
	if err != nil {
		return bosherr.WrapError(err, "Copying file")
	}

	return nil
}

func (fs *osFileSystem) CopyDir(srcPath, dstPath string) error {
	fs.logger.Debug(fs.logTag, "Copying dir '%s' to '%s'", srcPath, dstPath)

	sourceInfo, err := fs.Stat(srcPath)
	if err != nil {
		return bosherr.WrapErrorf(err, "Reading dir stats for '%s'", srcPath)
	}

	// create destination dir with same permissions as source dir
	err = fs.MkdirAll(dstPath, sourceInfo.Mode())
	if err != nil {
		return bosherr.WrapErrorf(err, "Making destination dir '%s'", dstPath)
	}

	files, err := fs.listDirContents(srcPath)
	if err != nil {
		return bosherr.WrapErrorf(err, "Listing contents of source dir '%s", srcPath)
	}

	for _, file := range files {
		fileSrcPath := filepath.Join(srcPath, file.Name())
		fileDstPath := filepath.Join(dstPath, file.Name())

		if file.IsDir() {
			err = fs.CopyDir(fileSrcPath, fileDstPath)
			if err != nil {
				return bosherr.WrapErrorf(err, "Copying sub-dir '%s' to '%s'", fileSrcPath, fileDstPath)
			}
		} else {
			err = fs.CopyFile(fileSrcPath, fileDstPath)
			if err != nil {
				return bosherr.WrapErrorf(err, "Copying file '%s' to '%s'", fileSrcPath, fileDstPath)
			}
		}
	}

	return nil
}

func (fs *osFileSystem) listDirContents(dirPath string) ([]os.FileInfo, error) {
	file, err := fs.openFile(dirPath, os.O_RDONLY, 0)
	if err != nil {
		return nil, bosherr.WrapErrorf(err, "Opening dir '%s' for reading", dirPath)
	}
	defer file.Close()

	files, err := file.Readdir(-1)
	if err != nil {
		return nil, bosherr.WrapErrorf(err, "Reading dir '%s' contents", dirPath)
	}

	return files, nil
}

func (fs *osFileSystem) TempFile(prefix string) (file File, err error) {
	fs.logger.Debug(fs.logTag, "Creating temp file with prefix %s", prefix)
	if fs.tempRoot == "" && fs.requiresTempRoot {
		return nil, errors.New("Set a temp directory root with ChangeTempRoot before making temp files")
	}
	return ioutil.TempFile(fs.tempRoot, prefix)
}

func (fs *osFileSystem) TempDir(prefix string) (path string, err error) {
	fs.logger.Debug(fs.logTag, "Creating temp dir with prefix %s", prefix)
	if fs.tempRoot == "" && fs.requiresTempRoot {
		return "", errors.New("Set a temp directory root with ChangeTempRoot before making temp directories")
	}
	return ioutil.TempDir(fs.tempRoot, prefix)
}

func (fs *osFileSystem) ChangeTempRoot(tempRootPath string) error {
	err := fs.MkdirAll(tempRootPath, os.ModePerm)
	if err != nil {
		return err
	}
	fs.tempRoot = tempRootPath
	return nil
}

func (fs *osFileSystem) RemoveAll(fileOrDir string) (err error) {
	fs.logger.Debug(fs.logTag, "Remove all %s", fileOrDir)
	err = fsWrapper.RemoveAll(fileOrDir)
	return
}

func (fs *osFileSystem) Glob(pattern string) (matches []string, err error) {
	fs.logger.Debug(fs.logTag, "Glob '%s'", pattern)
	return filepath.Glob(pattern)
}

func (fs *osFileSystem) RecursiveGlob(pattern string) (matches []string, err error) {
	fs.logger.Debug(fs.logTag, "RecursiveGlob '%s'", pattern)
	return doublestar.Glob(pattern)
}

func (fs *osFileSystem) Walk(root string, walkFunc filepath.WalkFunc) error {
	return filepath.Walk(root, walkFunc)
}

func (fs *osFileSystem) runCommand(cmd string) (string, error) {
	var stdout bytes.Buffer
	shCmd := exec.Command("sh", "-c", cmd)
	shCmd.Stdout = &stdout
	if err := shCmd.Run(); err != nil {
		return "", err
	}

	return strings.TrimSpace(stdout.String()), nil
}
