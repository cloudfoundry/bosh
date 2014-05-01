package packageapplier

type PackageApplierProvider interface {
	Root() PackageApplier
	JobSpecific(jobName string) PackageApplier
}
