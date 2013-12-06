package applier

import (
	as "bosh/agent/applier/applyspec"
	bc "bosh/agent/applier/bundlecollection"
	models "bosh/agent/applier/models"
	pa "bosh/agent/applier/packageapplier"
	bosherr "bosh/errors"
	boshsettings "bosh/settings"
)

type concreteApplier struct {
	jobsBc            bc.BundleCollection
	packageApplier    pa.PackageApplier
	logrotateDelegate LogrotateDelegate
}

func NewConcreteApplier(
	jobsBc bc.BundleCollection,
	packageApplier pa.PackageApplier,
	logrotateDelegate LogrotateDelegate,
) *concreteApplier {
	return &concreteApplier{
		jobsBc:            jobsBc,
		packageApplier:    packageApplier,
		logrotateDelegate: logrotateDelegate,
	}
}

func (s *concreteApplier) Apply(applySpec as.ApplySpec) error {
	for _, job := range applySpec.Jobs() {
		err := s.applyJob(job)
		if err != nil {
			return err
		}
	}

	for _, pkg := range applySpec.Packages() {
		err := s.packageApplier.Apply(pkg)
		if err != nil {
			return err
		}
	}

	return s.setUpLogrotate(applySpec)
}

func (s *concreteApplier) applyJob(job models.Job) error {
	_, err := s.jobsBc.Install(job)
	if err != nil {
		return err
	}

	err = s.jobsBc.Enable(job)
	if err != nil {
		return err
	}

	return nil
}

func (s *concreteApplier) setUpLogrotate(applySpec as.ApplySpec) error {
	err := s.logrotateDelegate.SetupLogrotate(
		boshsettings.VCAP_USERNAME,
		boshsettings.VCAP_BASE_DIR,
		applySpec.MaxLogFileSize(),
	)
	if err != nil {
		err = bosherr.WrapError(err, "Logrotate setup failed")
	}
	return err
}
