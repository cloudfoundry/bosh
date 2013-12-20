package applier

import (
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakeja "bosh/agent/applier/jobapplier/fakes"
	models "bosh/agent/applier/models"
	fakepa "bosh/agent/applier/packageapplier/fakes"
	fakemon "bosh/monitor/fakes"
	boshsettings "bosh/settings"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

type FakeLogRotateDelegate struct {
	SetupLogrotateErr  error
	SetupLogrotateArgs SetupLogrotateArgs
}

type SetupLogrotateArgs struct {
	GroupName string
	BasePath  string
	Size      string
}

func (d *FakeLogRotateDelegate) SetupLogrotate(groupName, basePath, size string) (err error) {
	d.SetupLogrotateArgs = SetupLogrotateArgs{groupName, basePath, size}

	if d.SetupLogrotateErr != nil {
		err = d.SetupLogrotateErr
	}

	return
}

func TestApplyAppliesJobs(t *testing.T) {
	jobApplier, _, _, _, applier := buildApplier()
	job := buildJob()

	err := applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})
	assert.NoError(t, err)
	assert.Equal(t, jobApplier.AppliedJobs, []models.Job{job})
}

func TestApplyErrsWhenApplyingJobsErrs(t *testing.T) {
	jobApplier, _, _, _, applier := buildApplier()
	job := buildJob()

	jobApplier.ApplyError = errors.New("fake-apply-job-error")

	err := applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-apply-job-error")
}

func TestApplyAppliesPackages(t *testing.T) {
	_, packageApplier, _, _, applier := buildApplier()

	pkg1 := buildPackage()
	pkg2 := buildPackage()

	err := applier.Apply(&fakeas.FakeApplySpec{PackageResults: []models.Package{pkg1, pkg2}})
	assert.NoError(t, err)
	assert.Equal(t, packageApplier.AppliedPackages, []models.Package{pkg1, pkg2})
}

func TestApplyErrsWhenApplyingPackagesErrs(t *testing.T) {
	_, packageApplier, _, _, applier := buildApplier()
	pkg := buildPackage()

	packageApplier.ApplyError = errors.New("fake-apply-package-error")

	err := applier.Apply(&fakeas.FakeApplySpec{PackageResults: []models.Package{pkg}})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-apply-package-error")
}

func TestApplyConfiguresJobs(t *testing.T) {
	jobApplier, _, _, monitor, applier := buildApplier()

	job1 := models.Job{Name: "fake-job-name-1", Version: "fake-version-name-1"}
	job2 := models.Job{Name: "fake-job-name-2", Version: "fake-version-name-2"}
	jobs := []models.Job{job1, job2}

	err := applier.Apply(&fakeas.FakeApplySpec{JobResults: jobs})
	assert.NoError(t, err)
	assert.Equal(t, jobApplier.ConfiguredJobs, []models.Job{job2, job1})
	assert.Equal(t, jobApplier.ConfiguredJobIndices, []int{0, 1})

	assert.True(t, monitor.Reloaded)
}

func TestApplyErrsIfMonitorFailsReload(t *testing.T) {
	_, _, _, monitor, applier := buildApplier()
	jobs := []models.Job{}
	monitor.ReloadErr = errors.New("error reloading monit")

	err := applier.Apply(&fakeas.FakeApplySpec{JobResults: jobs})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "error reloading monit")
}

func TestApplyErrsIfAJobFailsConfiguring(t *testing.T) {
	jobApplier, _, _, _, applier := buildApplier()
	jobApplier.ConfigureError = errors.New("error configuring job")

	job := models.Job{Name: "fake-job-name-1", Version: "fake-version-name-1"}

	err := applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "error configuring job")
}

func TestApplySetsUpLogrotation(t *testing.T) {
	_, _, platform, _, applier := buildApplier()

	err := applier.Apply(&fakeas.FakeApplySpec{MaxLogFileSizeResult: "fake-size"})
	assert.NoError(t, err)
	assert.Equal(t, platform.SetupLogrotateArgs, SetupLogrotateArgs{
		GroupName: boshsettings.VCAP_USERNAME,
		BasePath:  boshsettings.VCAP_BASE_DIR,
		Size:      "fake-size",
	})
}

func TestApplyErrsIfSetupLogrotateFails(t *testing.T) {
	_, _, platform, _, applier := buildApplier()

	platform.SetupLogrotateErr = errors.New("fake-msg")

	err := applier.Apply(&fakeas.FakeApplySpec{})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Logrotate setup failed: fake-msg")
}

func buildApplier() (
	*fakeja.FakeJobApplier,
	*fakepa.FakePackageApplier,
	*FakeLogRotateDelegate,
	*fakemon.FakeMonitor,
	Applier,
) {
	jobApplier := fakeja.NewFakeJobApplier()
	packageApplier := fakepa.NewFakePackageApplier()
	platform := &FakeLogRotateDelegate{}
	monitor := fakemon.NewFakeMonitor()
	applier := NewConcreteApplier(jobApplier, packageApplier, platform, monitor)
	return jobApplier, packageApplier, platform, monitor, applier
}

func buildJob() models.Job {
	return models.Job{Name: "fake-job-name", Version: "fake-version-name"}
}

func buildPackage() models.Package {
	return models.Package{Name: "fake-package-name", Version: "fake-package-name"}
}
