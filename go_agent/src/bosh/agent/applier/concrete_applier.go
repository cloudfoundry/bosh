package applier

import (
	as "bosh/agent/applier/applyspec"
	ja "bosh/agent/applier/jobapplier"
	pa "bosh/agent/applier/packageapplier"
	bosherr "bosh/errors"
	boshsettings "bosh/settings"
)

type concreteApplier struct {
	jobApplier        ja.JobApplier
	packageApplier    pa.PackageApplier
	logrotateDelegate LogrotateDelegate
}

func NewConcreteApplier(
	jobApplier ja.JobApplier,
	packageApplier pa.PackageApplier,
	logrotateDelegate LogrotateDelegate,
) *concreteApplier {
	return &concreteApplier{
		jobApplier:        jobApplier,
		packageApplier:    packageApplier,
		logrotateDelegate: logrotateDelegate,
	}
}

func (s *concreteApplier) Apply(applySpec as.ApplySpec) (err error) {
	for _, job := range applySpec.Jobs() {
		err = s.jobApplier.Apply(job)
		if err != nil {
			err = bosherr.WrapError(err, "Applying job %s", job.Name)
			return
		}
	}

	for _, pkg := range applySpec.Packages() {
		err = s.packageApplier.Apply(pkg)
		if err != nil {
			err = bosherr.WrapError(err, "Applying package %s", pkg.Name)
			return
		}
	}

	err = s.setUpLogrotate(applySpec)
	return
}

func (s *concreteApplier) setUpLogrotate(applySpec as.ApplySpec) (err error) {
	err = s.logrotateDelegate.SetupLogrotate(
		boshsettings.VCAP_USERNAME,
		boshsettings.VCAP_BASE_DIR,
		applySpec.MaxLogFileSize(),
	)
	if err != nil {
		err = bosherr.WrapError(err, "Logrotate setup failed")
	}
	return
}
