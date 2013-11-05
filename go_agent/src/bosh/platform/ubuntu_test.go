package platform

import (
	"bosh/settings"
	testsys "bosh/system/testhelpers"
	"github.com/stretchr/testify/assert"
	"testing"
)

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
