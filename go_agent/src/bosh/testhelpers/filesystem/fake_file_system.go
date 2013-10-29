package filesystem

import "os"

type FakeFileSystem struct {
	Files map[string]*FakeFileStats

	HomeDirUsername string
	HomeDirHomeDir  string
}

type FakeFileStats struct {
	FileMode    os.FileMode
	Username    string
	CreatedWith string
	Content     string
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
	stats.CreatedWith = "MkdirAll"
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

func (fs *FakeFileSystem) WriteToFile(path, content string) (err error) {
	stats := fs.getOrCreateFile(path)
	stats.CreatedWith = "WriteToFile"
	stats.Content = content
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
