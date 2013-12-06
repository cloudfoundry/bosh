package applier

import (
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakebc "bosh/agent/applier/bundlecollection/fakes"
	models "bosh/agent/applier/models"
	fakepa "bosh/agent/applier/packageapplier/fakes"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestApplyInstallsAndEnablesJobs(t *testing.T) {
	jobsBc, _, _, applier := buildApplier()
	job := buildJob()

	err := applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})
	assert.NoError(t, err)
	assert.True(t, jobsBc.IsInstalled(job))
	assert.True(t, jobsBc.IsEnabled(job))
}

func TestApplyErrsWhenJobInstallFails(t *testing.T) {
	jobsBc, _, _, applier := buildApplier()
	job := buildJob()

	jobsBc.InstallError = errors.New("fake-install-error")

	err := applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-install-error")
}

func TestApplyErrsWhenJobEnableFails(t *testing.T) {
	jobsBc, _, _, applier := buildApplier()
	job := buildJob()

	jobsBc.EnableError = errors.New("fake-enable-error")

	err := applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-enable-error")
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

	packageApplier.ApplyError = errors.New("fake-apply-error")

	err := applier.Apply(&fakeas.FakeApplySpec{PackageResults: []models.Package{pkg}})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-apply-error")
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
	*fakebc.FakeBundleCollection,
	*fakepa.FakePackageApplier,
	*fakeplatform.FakePlatform,
	Applier,
) {
	jobsBc := fakebc.NewFakeBundleCollection()
	packageApplier := fakepa.NewFakePackageApplier()
	platform := fakeplatform.NewFakePlatform()
	applier := NewConcreteApplier(jobsBc, packageApplier, platform)
	return jobsBc, packageApplier, platform, applier
}

func buildJob() models.Job {
	return models.Job{Name: "fake-job-name", Version: "fake-version-name"}
}

func buildPackage() models.Package {
	return models.Package{Name: "fake-package-name", Version: "fake-package-name"}
}
