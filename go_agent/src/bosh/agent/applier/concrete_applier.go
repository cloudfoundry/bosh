package applier

import (
	as "bosh/agent/applier/applyspec"
	ja "bosh/agent/applier/jobapplier"
	pa "bosh/agent/applier/packageapplier"
	bosherr "bosh/errors"
	boshmon "bosh/monitor"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
)

type concreteApplier struct {
	jobApplier        ja.JobApplier
	packageApplier    pa.PackageApplier
	logrotateDelegate LogrotateDelegate
	monitor           boshmon.Monitor
	dirProvider       boshdirs.DirectoriesProvider
}

func NewConcreteApplier(
	jobApplier ja.JobApplier,
	packageApplier pa.PackageApplier,
	logrotateDelegate LogrotateDelegate,
	monitor boshmon.Monitor,
	dirProvider boshdirs.DirectoriesProvider,
) *concreteApplier {
	return &concreteApplier{
		jobApplier:        jobApplier,
		packageApplier:    packageApplier,
		logrotateDelegate: logrotateDelegate,
		monitor:           monitor,
		dirProvider:       dirProvider,
	}
}

func (a *concreteApplier) Apply(applySpec as.ApplySpec) (err error) {
	jobs := applySpec.Jobs()
	for _, job := range jobs {
		err = a.jobApplier.Apply(job)
		if err != nil {
			err = bosherr.WrapError(err, "Applying job %s", job.Name)
			return
		}
	}

	for _, pkg := range applySpec.Packages() {
		err = a.packageApplier.Apply(pkg)
		if err != nil {
			err = bosherr.WrapError(err, "Applying package %s", pkg.Name)
			return
		}
	}

	for i := 0; i < len(jobs); i++ {
		job := jobs[len(jobs)-1-i]

		err = a.jobApplier.Configure(job, i)
		if err != nil {
			err = bosherr.WrapError(err, "Configuring job %s", job.Name)
			return
		}
	}

	err = a.monitor.Reload()
	if err != nil {
		err = bosherr.WrapError(err, "Reloading monitor")
		return
	}

	err = a.setUpLogrotate(applySpec)
	return
}

func (a *concreteApplier) setUpLogrotate(applySpec as.ApplySpec) (err error) {
	err = a.logrotateDelegate.SetupLogrotate(
		boshsettings.VCAP_USERNAME,
		a.dirProvider.BaseDir(),
		applySpec.MaxLogFileSize(),
	)
	if err != nil {
		err = bosherr.WrapError(err, "Logrotate setup failed")
	}
	return
}
