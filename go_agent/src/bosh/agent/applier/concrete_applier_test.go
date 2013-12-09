package applier

import (
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakeja "bosh/agent/applier/jobapplier/fakes"
	models "bosh/agent/applier/models"
	fakepa "bosh/agent/applier/packageapplier/fakes"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestApplyAppliesJobs(t *testing.T) {
	jobApplier, _, _, applier := buildApplier()
	job := buildJob()

	err := applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})
	assert.NoError(t, err)
	assert.Equal(t, jobApplier.AppliedJobs, []models.Job{job})
}

func TestApplyErrsWhenApplyingJobsErrs(t *testing.T) {
	jobApplier, _, _, applier := buildApplier()
	job := buildJob()

	jobApplier.ApplyError = errors.New("fake-apply-job-error")

	err := applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-apply-job-error")
}

func TestApplyAppliesPackages(t *testing.T) {
	_, packageApplier, _, applier := buildApplier()

	pkg1 := buildPackage()
	pkg2 := buildPackage()

	err := applier.Apply(&fakeas.FakeApplySpec{PackageResults: []models.Package{pkg1, pkg2}})
	assert.NoError(t, err)
	assert.Equal(t, packageApplier.AppliedPackages, []models.Package{pkg1, pkg2})
}

func TestApplyErrsWhenApplyingPackagesErrs(t *testing.T) {
	_, packageApplier, _, applier := buildApplier()
	pkg := buildPackage()

	packageApplier.ApplyError = errors.New("fake-apply-package-error")

	err := applier.Apply(&fakeas.FakeApplySpec{PackageResults: []models.Package{pkg}})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-apply-package-error")
}

func TestApplySetsUpLogrotation(t *testing.T) {
	_, _, platform, applier := buildApplier()

	err := applier.Apply(&fakeas.FakeApplySpec{MaxLogFileSizeResult: "fake-size"})
	assert.NoError(t, err)
	assert.Equal(t, platform.SetupLogrotateArgs, fakeplatform.SetupLogrotateArgs{
		GroupName: boshsettings.VCAP_USERNAME,
		BasePath:  boshsettings.VCAP_BASE_DIR,
		Size:      "fake-size",
	})
}

func TestApplyErrsIfSetupLogrotateFails(t *testing.T) {
	_, _, platform, applier := buildApplier()

	platform.SetupLogrotateErr = errors.New("fake-msg")

	err := applier.Apply(&fakeas.FakeApplySpec{})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Logrotate setup failed: fake-msg")
}

func buildApplier() (
	*fakeja.FakeJobApplier,
	*fakepa.FakePackageApplier,
	*fakeplatform.FakePlatform,
	Applier,
) {
	jobApplier := fakeja.NewFakeJobApplier()
	packageApplier := fakepa.NewFakePackageApplier()
	platform := fakeplatform.NewFakePlatform()
	applier := NewConcreteApplier(jobApplier, packageApplier, platform)
	return jobApplier, packageApplier, platform, applier
}

func buildJob() models.Job {
	return models.Job{Name: "fake-job-name", Version: "fake-version-name"}
}

func buildPackage() models.Package {
	return models.Package{Name: "fake-package-name", Version: "fake-package-name"}
}
