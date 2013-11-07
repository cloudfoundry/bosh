package platform

import (
	testdisk "bosh/platform/disk/testhelpers"
	testsys "bosh/system/testhelpers"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestUbuntuGetCpuLoad(t *testing.T) {
	fakeFs, fakeCmdRunner, fakePartitioner, fakeFormatter := getUbuntuSysStatsDependencies()
	ubuntu := newUbuntuPlatform(fakeFs, fakeCmdRunner, fakePartitioner, fakeFormatter)

	load, err := ubuntu.GetCpuLoad()
	assert.NoError(t, err)
	assert.True(t, load.One > 0)
	assert.True(t, load.Five > 0)
	assert.True(t, load.Fifteen > 0)
}

func TestUbuntuGetCpuStats(t *testing.T) {
	fakeFs, fakeCmdRunner, fakePartitioner, fakeFormatter := getUbuntuSysStatsDependencies()
	ubuntu := newUbuntuPlatform(fakeFs, fakeCmdRunner, fakePartitioner, fakeFormatter)

	stats, err := ubuntu.GetCpuStats()
	assert.NoError(t, err)
	assert.True(t, stats.User > 0)
	assert.True(t, stats.Sys > 0)
	assert.True(t, stats.Total > 0)
}

func TestUbuntuGetMemStats(t *testing.T) {
	fakeFs, fakeCmdRunner, fakePartitioner, fakeFormatter := getUbuntuSysStatsDependencies()
	ubuntu := newUbuntuPlatform(fakeFs, fakeCmdRunner, fakePartitioner, fakeFormatter)

	stats, err := ubuntu.GetMemStats()
	assert.NoError(t, err)
	assert.True(t, stats.Total > 0)
	assert.True(t, stats.Used > 0)
}

func TestUbuntuGetSwapStats(t *testing.T) {
	fakeFs, fakeCmdRunner, fakePartitioner, fakeFormatter := getUbuntuSysStatsDependencies()
	ubuntu := newUbuntuPlatform(fakeFs, fakeCmdRunner, fakePartitioner, fakeFormatter)

	stats, err := ubuntu.GetSwapStats()
	assert.NoError(t, err)
	assert.True(t, stats.Total > 0)
}

func TestUbuntuGetDiskStats(t *testing.T) {
	fakeFs, fakeCmdRunner, fakePartitioner, fakeFormatter := getUbuntuSysStatsDependencies()
	ubuntu := newUbuntuPlatform(fakeFs, fakeCmdRunner, fakePartitioner, fakeFormatter)

	stats, err := ubuntu.GetDiskStats("/")
	assert.NoError(t, err)
	assert.True(t, stats.Total > 0)
	assert.True(t, stats.Used > 0)
	assert.True(t, stats.InodeTotal > 0)
	assert.True(t, stats.InodeUsed > 0)
}

func getUbuntuSysStatsDependencies() (
	fs *testsys.FakeFileSystem,
	runner *testsys.FakeCmdRunner,
	partitioner *testdisk.FakePartitioner,
	formatter *testdisk.FakeFormatter) {

	fs = &testsys.FakeFileSystem{}
	runner = &testsys.FakeCmdRunner{}
	partitioner = &testdisk.FakePartitioner{}
	formatter = &testdisk.FakeFormatter{}
	return
}
