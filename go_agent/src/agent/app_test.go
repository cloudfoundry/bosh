package agent

import (
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	testagent "testhelpers/agent"
	"testing"
)

func TestRunSetsUpSsh(t *testing.T) {
	fakeFs := &testagent.FakeFileSystem{
		HomeDirHomeDir: "/some/home/dir",
	}

	fakeInfrastructure := &testagent.FakeInfrastructure{
		PublicKey: "some public key",
	}

	Run(fakeFs, fakeInfrastructure)

	sshDirPath := "/some/home/dir/.ssh"
	sshDirStat := fakeFs.GetFileTestStat(sshDirPath)

	assert.Equal(t, fakeFs.HomeDirUsername, "vcap")

	assert.NotNil(t, sshDirStat)
	assert.Equal(t, sshDirStat.CreatedWith, "MkdirAll")
	assert.Equal(t, sshDirStat.FileMode, os.FileMode(0700))
	assert.Equal(t, sshDirStat.Username, "vcap")

	authKeysStat := fakeFs.GetFileTestStat(filepath.Join(sshDirPath, "authorized_keys"))

	assert.NotNil(t, authKeysStat)
	assert.Equal(t, authKeysStat.CreatedWith, "WriteToFile")
	assert.Equal(t, authKeysStat.FileMode, os.FileMode(0600))
	assert.Equal(t, authKeysStat.Username, "vcap")
	assert.Equal(t, authKeysStat.Content, "some public key")
}
