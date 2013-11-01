package bootstrap

import (
	"bosh/settings"
	testfs "bosh/testhelpers/filesystem"
	testinf "bosh/testhelpers/infrastructure"
	testplatform "bosh/testhelpers/platform"
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"testing"
)

func TestRunSetsUpSsh(t *testing.T) {
	fakeFs, fakeInfrastructure, fakePlatform := getBootstrapDependencies()
	fakeFs.HomeDirHomeDir = "/some/home/dir"
	fakeInfrastructure.PublicKey = "some public key"

	boot := New(fakeFs, fakeInfrastructure, fakePlatform)
	boot.Run()

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

func TestRunGetsSettingsFromTheInfrastructure(t *testing.T) {
	expectedSettings := settings.Settings{
		AgentId: "123-456-789",
	}

	fakeFs, fakeInfrastructure, fakePlatform := getBootstrapDependencies()
	fakeInfrastructure.Settings = expectedSettings

	boot := New(fakeFs, fakeInfrastructure, fakePlatform)
	boot.Run()

	settingsFileStat := fakeFs.GetFileTestStat(VCAP_BASE_DIR + "/bosh/settings.json")
	settingsJson, err := json.Marshal(expectedSettings)
	assert.NoError(t, err)

	assert.NotNil(t, settingsFileStat)
	assert.Equal(t, settingsFileStat.CreatedWith, "WriteToFile")
	assert.Equal(t, settingsFileStat.Content, string(settingsJson))
}

func TestRunSetsUpNetworking(t *testing.T) {
	s := settings.Settings{
		Networks: settings.Networks{
			"bosh": settings.NetworkSettings{},
		},
	}

	fakeFs, fakeInfrastructure, fakePlatform := getBootstrapDependencies()
	fakeInfrastructure.Settings = s

	boot := New(fakeFs, fakeInfrastructure, fakePlatform)
	boot.Run()

	assert.Equal(t, fakeInfrastructure.SetupNetworkingDelegate, fakePlatform)
	assert.Equal(t, fakeInfrastructure.SetupNetworkingNetworks, s.Networks)
}

func getBootstrapDependencies() (fs *testfs.FakeFileSystem, inf *testinf.FakeInfrastructure, p *testplatform.FakePlatform) {
	fs = &testfs.FakeFileSystem{}
	inf = &testinf.FakeInfrastructure{}
	p = &testplatform.FakePlatform{}
	return
}
