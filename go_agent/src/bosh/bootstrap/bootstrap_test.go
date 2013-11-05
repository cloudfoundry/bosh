package bootstrap

import (
	testinf "bosh/infrastructure/testhelpers"
	testplatform "bosh/platform/testhelpers"
	"bosh/settings"
	testsys "bosh/system/testhelpers"
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestRunSetsUpSsh(t *testing.T) {
	fakeFs, fakeInfrastructure, fakePlatform := getBootstrapDependencies()
	boot := New(fakeFs, fakeInfrastructure, fakePlatform)
	boot.Run()

	assert.Equal(t, fakeInfrastructure.SetupSshDelegate, fakePlatform)
	assert.Equal(t, fakeInfrastructure.SetupSshUsername, "vcap")
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

func getBootstrapDependencies() (fs *testsys.FakeFileSystem, inf *testinf.FakeInfrastructure, p *testplatform.FakePlatform) {
	fs = &testsys.FakeFileSystem{}
	inf = &testinf.FakeInfrastructure{}
	p = &testplatform.FakePlatform{}
	return
}
