package applier_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	. "bosh/agent/applier"
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakeja "bosh/agent/applier/jobapplier/fakes"
	models "bosh/agent/applier/models"
	fakepa "bosh/agent/applier/packageapplier/fakes"
	fakejobsuper "bosh/jobsupervisor/fakes"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
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

func (d *FakeLogRotateDelegate) SetupLogrotate(groupName, basePath, size string) error {
	d.SetupLogrotateArgs = SetupLogrotateArgs{groupName, basePath, size}
	if d.SetupLogrotateErr != nil {
		return d.SetupLogrotateErr
	}
	return nil
}

func buildJob() models.Job {
	return models.Job{Name: "fake-job-name", Version: "fake-version-name"}
}

func buildPackage() models.Package {
	return models.Package{Name: "fake-package-name", Version: "fake-package-name"}
}

func init() {
	Describe("concreteApplier", func() {
		var (
			jobApplier        *fakeja.FakeJobApplier
			packageApplier    *fakepa.FakePackageApplier
			logRotateDelegate *FakeLogRotateDelegate
			jobSupervisor     *fakejobsuper.FakeJobSupervisor
			applier           Applier
		)

		BeforeEach(func() {
			jobApplier = fakeja.NewFakeJobApplier()
			packageApplier = fakepa.NewFakePackageApplier()
			logRotateDelegate = &FakeLogRotateDelegate{}
			jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
			applier = NewConcreteApplier(
				jobApplier,
				packageApplier,
				logRotateDelegate,
				jobSupervisor,
				boshdirs.NewDirectoriesProvider("/fake-base-dir"),
			)
		})

		It("removes all jobs", func() {
			err := applier.Apply(&fakeas.FakeApplySpec{})
			Expect(err).ToNot(HaveOccurred())

			Expect(jobSupervisor.RemovedAllJobs).To(BeTrue())
		})

		It("removes all previous jobs before starting to apply jobs", func() {
			// force remove all error
			jobSupervisor.RemovedAllJobsErr = errors.New("fake-remove-all-jobs-error")

			job := buildJob()
			applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})

			// check that jobs were not applied before removing all other jobs
			Expect(jobApplier.AppliedJobs).To(Equal([]models.Job{}))
		})

		It("returns error if removing all jobs fails", func() {
			jobSupervisor.RemovedAllJobsErr = errors.New("fake-remove-all-jobs-error")

			err := applier.Apply(&fakeas.FakeApplySpec{})
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-remove-all-jobs-error"))
		})

		It("apply applies jobs", func() {
			job := buildJob()

			err := applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), jobApplier.AppliedJobs, []models.Job{job})
		})

		It("apply errs when applying jobs errs", func() {
			job := buildJob()

			jobApplier.ApplyError = errors.New("fake-apply-job-error")

			err := applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-apply-job-error")
		})

		It("apply applies packages", func() {
			pkg1 := buildPackage()
			pkg2 := buildPackage()

			err := applier.Apply(&fakeas.FakeApplySpec{PackageResults: []models.Package{pkg1, pkg2}})
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), packageApplier.AppliedPackages, []models.Package{pkg1, pkg2})
		})

		It("apply errs when applying packages errs", func() {
			pkg := buildPackage()

			packageApplier.ApplyError = errors.New("fake-apply-package-error")

			err := applier.Apply(&fakeas.FakeApplySpec{PackageResults: []models.Package{pkg}})
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-apply-package-error")
		})

		It("apply configures jobs", func() {
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
			jobs := []models.Job{}
			jobSupervisor.ReloadErr = errors.New("error reloading monit")

			err := applier.Apply(&fakeas.FakeApplySpec{JobResults: jobs})
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "error reloading monit")
		})

		It("apply errs if a job fails configuring", func() {
			jobApplier.ConfigureError = errors.New("error configuring job")

			job := models.Job{Name: "fake-job-name-1", Version: "fake-version-name-1"}

			err := applier.Apply(&fakeas.FakeApplySpec{JobResults: []models.Job{job}})
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "error configuring job")
		})

		It("apply sets up logrotation", func() {
			err := applier.Apply(&fakeas.FakeApplySpec{MaxLogFileSizeResult: "fake-size"})
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), logRotateDelegate.SetupLogrotateArgs, SetupLogrotateArgs{
				GroupName: boshsettings.VCAP_USERNAME,
				BasePath:  "/fake-base-dir",
				Size:      "fake-size",
			})
		})

		It("apply errs if setup logrotate fails", func() {
			logRotateDelegate.SetupLogrotateErr = errors.New("fake-msg")

			err := applier.Apply(&fakeas.FakeApplySpec{})
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "Logrotate setup failed: fake-msg")
		})
	})
}
