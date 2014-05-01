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
	boshuuid "bosh/uuid"
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
	return d.SetupLogrotateErr
}

func buildJob() models.Job {
	uuidGen := boshuuid.NewGenerator()
	uuid, err := uuidGen.Generate()
	Expect(err).ToNot(HaveOccurred())
	return models.Job{Name: "fake-job-name" + uuid, Version: "fake-version-name"}
}

func buildPackage() models.Package {
	uuidGen := boshuuid.NewGenerator()
	uuid, err := uuidGen.Generate()
	Expect(err).ToNot(HaveOccurred())
	return models.Package{Name: "fake-package-name" + uuid, Version: "fake-package-name"}
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

		Describe("Prepare", func() {
			It("prepares each jobs", func() {
				job := buildJob()

				err := applier.Prepare(
					&fakeas.FakeApplySpec{JobResults: []models.Job{job}},
				)
				Expect(err).ToNot(HaveOccurred())
				Expect(jobApplier.PreparedJobs).To(Equal([]models.Job{job}))
			})

			It("returns error when preparing jobs fails", func() {
				job := buildJob()

				jobApplier.PrepareError = errors.New("fake-prepare-job-error")

				err := applier.Prepare(
					&fakeas.FakeApplySpec{JobResults: []models.Job{job}},
				)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-prepare-job-error"))
			})

			It("prepares each packages", func() {
				pkg1 := buildPackage()
				pkg2 := buildPackage()

				err := applier.Prepare(
					&fakeas.FakeApplySpec{PackageResults: []models.Package{pkg1, pkg2}},
				)
				Expect(err).ToNot(HaveOccurred())
				Expect(packageApplier.PreparedPackages).To(Equal([]models.Package{pkg1, pkg2}))
			})

			It("returns error when preparing packages fails", func() {
				pkg := buildPackage()

				packageApplier.PrepareError = errors.New("fake-prepare-package-error")

				err := applier.Prepare(
					&fakeas.FakeApplySpec{PackageResults: []models.Package{pkg}},
				)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-prepare-package-error"))
			})
		})

		Describe("Apply", func() {
			It("removes all jobs from job supervisor", func() {
				err := applier.Apply(&fakeas.FakeApplySpec{}, &fakeas.FakeApplySpec{})
				Expect(err).ToNot(HaveOccurred())

				Expect(jobSupervisor.RemovedAllJobs).To(BeTrue())
			})

			It("removes all previous jobs from job supervisor before starting to apply jobs", func() {
				// force remove all error
				jobSupervisor.RemovedAllJobsErr = errors.New("fake-remove-all-jobs-error")

				job := buildJob()
				applier.Apply(
					&fakeas.FakeApplySpec{},
					&fakeas.FakeApplySpec{JobResults: []models.Job{job}},
				)

				// check that jobs were not applied before removing all other jobs
				Expect(jobApplier.AppliedJobs).To(Equal([]models.Job{}))
			})

			It("returns error if removing all jobs from job supervisor fails", func() {
				jobSupervisor.RemovedAllJobsErr = errors.New("fake-remove-all-jobs-error")

				err := applier.Apply(&fakeas.FakeApplySpec{}, &fakeas.FakeApplySpec{})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-remove-all-jobs-error"))
			})

			It("apply applies jobs", func() {
				job := buildJob()

				err := applier.Apply(
					&fakeas.FakeApplySpec{},
					&fakeas.FakeApplySpec{JobResults: []models.Job{job}},
				)
				Expect(err).ToNot(HaveOccurred())
				Expect(jobApplier.AppliedJobs).To(Equal([]models.Job{job}))
			})

			It("apply errs when applying jobs errs", func() {
				job := buildJob()

				jobApplier.ApplyError = errors.New("fake-apply-job-error")

				err := applier.Apply(
					&fakeas.FakeApplySpec{},
					&fakeas.FakeApplySpec{JobResults: []models.Job{job}},
				)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-apply-job-error"))
			})

			It("asked jobApplier to keep only the jobs in the desired and current specs", func() {
				currentJob := buildJob()
				desiredJob := buildJob()

				err := applier.Apply(
					&fakeas.FakeApplySpec{JobResults: []models.Job{currentJob}},
					&fakeas.FakeApplySpec{JobResults: []models.Job{desiredJob}},
				)
				Expect(err).ToNot(HaveOccurred())

				Expect(jobApplier.KeepOnlyJobs).To(Equal([]models.Job{currentJob, desiredJob}))
			})

			It("returns error when jobApplier fails to keep only the jobs in the desired and current specs", func() {
				jobApplier.KeepOnlyErr = errors.New("fake-keep-only-error")

				currentJob := buildJob()
				desiredJob := buildJob()

				err := applier.Apply(
					&fakeas.FakeApplySpec{JobResults: []models.Job{currentJob}},
					&fakeas.FakeApplySpec{JobResults: []models.Job{desiredJob}},
				)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-keep-only-error"))
			})

			It("apply applies packages", func() {
				pkg1 := buildPackage()
				pkg2 := buildPackage()

				err := applier.Apply(
					&fakeas.FakeApplySpec{},
					&fakeas.FakeApplySpec{PackageResults: []models.Package{pkg1, pkg2}},
				)
				Expect(err).ToNot(HaveOccurred())
				Expect(packageApplier.AppliedPackages).To(Equal([]models.Package{pkg1, pkg2}))
			})

			It("apply errs when applying packages errs", func() {
				pkg := buildPackage()

				packageApplier.ApplyError = errors.New("fake-apply-package-error")

				err := applier.Apply(
					&fakeas.FakeApplySpec{},
					&fakeas.FakeApplySpec{PackageResults: []models.Package{pkg}},
				)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-apply-package-error"))
			})

			It("asked packageApplier to keep only the packages in the desired and current specs", func() {
				currentPkg := buildPackage()
				desiredPkg := buildPackage()

				err := applier.Apply(
					&fakeas.FakeApplySpec{PackageResults: []models.Package{currentPkg}},
					&fakeas.FakeApplySpec{PackageResults: []models.Package{desiredPkg}},
				)
				Expect(err).ToNot(HaveOccurred())
				Expect(packageApplier.KeptOnlyPackages).To(Equal([]models.Package{currentPkg, desiredPkg}))
			})

			It("returns error when packageApplier fails to keep only the packages in the desired and current specs", func() {
				packageApplier.KeepOnlyErr = errors.New("fake-keep-only-error")

				currentPkg := buildPackage()
				desiredPkg := buildPackage()

				err := applier.Apply(
					&fakeas.FakeApplySpec{PackageResults: []models.Package{currentPkg}},
					&fakeas.FakeApplySpec{PackageResults: []models.Package{desiredPkg}},
				)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-keep-only-error"))
			})

			It("apply configures jobs", func() {
				job1 := models.Job{Name: "fake-job-name-1", Version: "fake-version-name-1"}
				job2 := models.Job{Name: "fake-job-name-2", Version: "fake-version-name-2"}
				jobs := []models.Job{job1, job2}

				err := applier.Apply(&fakeas.FakeApplySpec{}, &fakeas.FakeApplySpec{JobResults: jobs})
				Expect(err).ToNot(HaveOccurred())
				Expect(jobApplier.ConfiguredJobs).To(Equal([]models.Job{job2, job1}))
				Expect(jobApplier.ConfiguredJobIndices).To(Equal([]int{0, 1}))

				Expect(jobSupervisor.Reloaded).To(BeTrue())
			})

			It("apply errs if monitor fails reload", func() {
				jobs := []models.Job{}
				jobSupervisor.ReloadErr = errors.New("error reloading monit")

				err := applier.Apply(&fakeas.FakeApplySpec{}, &fakeas.FakeApplySpec{JobResults: jobs})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("error reloading monit"))
			})

			It("apply errs if a job fails configuring", func() {
				jobApplier.ConfigureError = errors.New("error configuring job")

				job := models.Job{Name: "fake-job-name-1", Version: "fake-version-name-1"}

				err := applier.Apply(
					&fakeas.FakeApplySpec{},
					&fakeas.FakeApplySpec{JobResults: []models.Job{job}},
				)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("error configuring job"))
			})

			It("apply sets up logrotation", func() {
				err := applier.Apply(
					&fakeas.FakeApplySpec{},
					&fakeas.FakeApplySpec{MaxLogFileSizeResult: "fake-size"},
				)
				Expect(err).ToNot(HaveOccurred())

				assert.Equal(GinkgoT(), logRotateDelegate.SetupLogrotateArgs, SetupLogrotateArgs{
					GroupName: boshsettings.VCAPUsername,
					BasePath:  "/fake-base-dir",
					Size:      "fake-size",
				})
			})

			It("apply errs if setup logrotate fails", func() {
				logRotateDelegate.SetupLogrotateErr = errors.New("fake-set-up-logrotate-error")

				err := applier.Apply(&fakeas.FakeApplySpec{}, &fakeas.FakeApplySpec{})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-set-up-logrotate-error"))
			})
		})
	})
}
