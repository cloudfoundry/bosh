package applier_test

import (
	. "bosh/agent/applier"
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakeja "bosh/agent/applier/jobapplier/fakes"
	models "bosh/agent/applier/models"
	fakepa "bosh/agent/applier/packageapplier/fakes"
	fakejobsuper "bosh/jobsupervisor/fakes"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
	"errors"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
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

func buildApplier() (
	*fakeja.FakeJobApplier,
	*fakepa.FakePackageApplier,
	*FakeLogRotateDelegate,
	*fakejobsuper.FakeJobSupervisor,
	Applier,
) {
	jobApplier := fakeja.NewFakeJobApplier()
	packageApplier := fakepa.NewFakePackageApplier()
	platform := &FakeLogRotateDelegate{}
	jobSupervisor := fakejobsuper.NewFakeJobSupervisor()
	applier := NewConcreteApplier(jobApplier, packageApplier, platform, jobSupervisor, boshdirs.NewDirectoriesProvider("/fake-base-dir"))
	return jobApplier, packageApplier, platform, jobSupervisor, applier
}

func buildJob() models.Job {
	return models.Job{Name: "fake-job-name", Version: "fake-version-name"}
}

func buildPackage() models.Package {
	return models.Package{Name: "fake-package-name", Version: "fake-package-name"}
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("apply applies jobs", func() {
			jobApplier, _, _, _, applier := buildApplier()
			job := buildJob()

			err := applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), jobApplier.AppliedJobs, []models.Job{job})
		})
		It("apply errs when applying jobs errs", func() {

			jobApplier, _, _, _, applier := buildApplier()
			job := buildJob()

			jobApplier.ApplyError = errors.New("fake-apply-job-error")

			err := applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-apply-job-error")
		})
		It("apply applies packages", func() {

			_, packageApplier, _, _, applier := buildApplier()

			pkg1 := buildPackage()
			pkg2 := buildPackage()

			err := applier.Apply(&fakeas.FakeApplySpec{PackageResults: []models.Package{pkg1, pkg2}})
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), packageApplier.AppliedPackages, []models.Package{pkg1, pkg2})
		})
		It("apply errs when applying packages errs", func() {

			_, packageApplier, _, _, applier := buildApplier()
			pkg := buildPackage()

			packageApplier.ApplyError = errors.New("fake-apply-package-error")

			err := applier.Apply(&fakeas.FakeApplySpec{PackageResults: []models.Package{pkg}})
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-apply-package-error")
		})
		It("apply configures jobs", func() {

			jobApplier, _, _, jobSupervisor, applier := buildApplier()

			job1 := models.Job{Name: "fake-job-name-1", Version: "fake-version-name-1"}
			job2 := models.Job{Name: "fake-job-name-2", Version: "fake-version-name-2"}
			jobs := []models.Job{job1, job2}

			err := applier.Apply(&fakeas.FakeApplySpec{JobResults: jobs})
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), jobApplier.ConfiguredJobs, []models.Job{job2, job1})
			assert.Equal(GinkgoT(), jobApplier.ConfiguredJobIndices, []int{0, 1})

			assert.True(GinkgoT(), jobSupervisor.Reloaded)
		})
		It("apply errs if monitor fails reload", func() {

			_, _, _, jobSupervisor, applier := buildApplier()
			jobs := []models.Job{}
			jobSupervisor.ReloadErr = errors.New("error reloading monit")

			err := applier.Apply(&fakeas.FakeApplySpec{JobResults: jobs})
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "error reloading monit")
		})
		It("apply errs if a job fails configuring", func() {

			jobApplier, _, _, _, applier := buildApplier()
			jobApplier.ConfigureError = errors.New("error configuring job")

			job := models.Job{Name: "fake-job-name-1", Version: "fake-version-name-1"}

			err := applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "error configuring job")
		})
		It("apply sets up logrotation", func() {

			_, _, platform, _, applier := buildApplier()

			err := applier.Apply(&fakeas.FakeApplySpec{MaxLogFileSizeResult: "fake-size"})
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), platform.SetupLogrotateArgs, SetupLogrotateArgs{
				GroupName: boshsettings.VCAP_USERNAME,
				BasePath:  "/fake-base-dir",
				Size:      "fake-size",
			})
		})
		It("apply errs if setup logrotate fails", func() {

			_, _, platform, _, applier := buildApplier()

			platform.SetupLogrotateErr = errors.New("fake-msg")

			err := applier.Apply(&fakeas.FakeApplySpec{})
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "Logrotate setup failed: fake-msg")
		})
	})
}
