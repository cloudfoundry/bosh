package applyspec

import (
	bcfakes "bosh/agent/applyspec/bundlecollection/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestApplyInstallsAndEnabledJobs(t *testing.T) {
	jobsBc, _, applier := buildApplier()
	job := buildJob()

	err := applier.Apply([]Job{job}, []Package{})
	assert.NoError(t, err)
	assert.True(t, jobsBc.IsInstalled(job))
	assert.True(t, jobsBc.IsEnabled(job))
}

func TestApplyErrsWhenJobInstallFails(t *testing.T) {
	jobsBc, _, applier := buildApplier()
	job := buildJob()

	jobsBc.InstallError = errors.New("fake-install-error")

	err := applier.Apply([]Job{job}, []Package{})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-install-error")
}

func TestApplyErrsWhenJobEnableFails(t *testing.T) {
	jobsBc, _, applier := buildApplier()
	job := buildJob()

	jobsBc.EnableError = errors.New("fake-enable-error")

	err := applier.Apply([]Job{job}, []Package{})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-enable-error")
}

func TestApplyInstallsAndEnablesPackages(t *testing.T) {
	_, packagesBc, applier := buildApplier()
	pkg := buildPackage()

	err := applier.Apply([]Job{}, []Package{pkg})
	assert.NoError(t, err)
	assert.True(t, packagesBc.IsInstalled(pkg))
	assert.True(t, packagesBc.IsEnabled(pkg))
}

func TestApplyErrsWhenPackageInstallFails(t *testing.T) {
	_, packagesBc, applier := buildApplier()
	pkg := buildPackage()

	packagesBc.InstallError = errors.New("fake-install-error")

	err := applier.Apply([]Job{}, []Package{pkg})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-install-error")
}

func TestApplyErrsWhenPackageEnableFails(t *testing.T) {
	_, packagesBc, applier := buildApplier()
	pkg := buildPackage()

	packagesBc.EnableError = errors.New("fake-enable-error")

	err := applier.Apply([]Job{}, []Package{pkg})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-enable-error")
}

func buildApplier() (*bcfakes.FakeBundleCollection, *bcfakes.FakeBundleCollection, Applier) {
	jobsBc := bcfakes.NewFakeBundleCollection()
	packagesBc := bcfakes.NewFakeBundleCollection()
	applier := NewConcreteApplier(jobsBc, packagesBc)
	return jobsBc, packagesBc, applier
}

func buildJob() Job {
	return Job{Name: "fake-job-name", Version: "fake-version-name"}
}

func buildPackage() Package {
	return Package{Name: "fake-package-name", Version: "fake-package-name"}
}
