package action

import (
	boshsettings "bosh/settings"
	testsys "bosh/system/testhelpers"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestRunSavesTheFirstArgumentToSpecJson(t *testing.T) {
	fakeFs := &testsys.FakeFileSystem{}

	apply := newApply(fakeFs)
	apply.Run([]string{"some spec content"})

	stats := fakeFs.GetFileTestStat(boshsettings.VCAP_BASE_DIR + "/bosh/spec.json")
	assert.Equal(t, "WriteToFile", stats.CreatedWith)
	assert.Equal(t, "some spec content", stats.Content)
}
