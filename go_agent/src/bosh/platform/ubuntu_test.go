package platform

import (
	"bosh/settings"
	testsys "bosh/system/testhelpers"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"testing"
)

func TestSetupSsh(t *testing.T) {
	fakeFs := &testsys.FakeFileSystem{}
	fakeFs.HomeDirHomeDir = "/some/home/dir"

	fakeCmdRunner := &testsys.FakeCmdRunner{}

	ubuntu := newUbuntuPlatform(fakeFs, fakeCmdRunner)
	ubuntu.SetupSsh("some public key", "vcap")

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

func TestSetupDhcp(t *testing.T) {
	networks := settings.Networks{
		"bosh": settings.NetworkSettings{
			Default: []string{"dns"},
			Dns:     []string{"xx.xx.xx.xx", "yy.yy.yy.yy", "zz.zz.zz.zz"},
		},
		"vip": settings.NetworkSettings{
			Default: []string{},
			Dns:     []string{"aa.aa.aa.aa"},
		},
	}

	fakeFs := &testsys.FakeFileSystem{}
	fakeCmdRunner := &testsys.FakeCmdRunner{}

	ubuntu := newUbuntuPlatform(fakeFs, fakeCmdRunner)
	ubuntu.SetupDhcp(networks)

	dhcpConfig := fakeFs.GetFileTestStat("/etc/dhcp3/dhclient.conf")
	assert.NotNil(t, dhcpConfig)
	assert.Contains(t, dhcpConfig.Content, "prepend domain-name-servers zz.zz.zz.zz;\nprepend domain-name-servers yy.yy.yy.yy;\nprepend domain-name-servers xx.xx.xx.xx;")

	assert.Equal(t, len(fakeCmdRunner.RunCommands), 2)
	assert.Equal(t, fakeCmdRunner.RunCommands[0], []string{"pkill", "dhclient3"})
	assert.Equal(t, fakeCmdRunner.RunCommands[1], []string{"/etc/init.d/networking", "restart"})
}
