package action

import (
	boshsettings "bosh/settings"
	testsys "bosh/system/testhelpers"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestRunSavesTheFirstArgumentToSpecJson(t *testing.T) {
	fakeFs := &testsys.FakeFileSystem{}
	payload := `{"method":"apply","reply_to":"foo","arguments":[{"deployment":"dummy-damien"}]}`

	apply := newApply(fakeFs)
	err := apply.Run(payload)
	assert.NoError(t, err)

	stats := fakeFs.GetFileTestStat(boshsettings.VCAP_BASE_DIR + "/bosh/spec.json")
	assert.Equal(t, "WriteToFile", stats.CreatedWith)
	assert.Equal(t, `{"deployment":"dummy-damien"}`, stats.Content)
}

func TestRunErrsWithZeroArguments(t *testing.T) {
	fakeFs := &testsys.FakeFileSystem{}
	payload := `{"method":"apply","reply_to":"foo","arguments":[]}`

	apply := newApply(fakeFs)
	err := apply.Run(payload)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Not enough arguments")
}
