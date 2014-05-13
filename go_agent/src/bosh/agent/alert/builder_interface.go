package alert

type Builder interface {
	Build(input MonitAlert) (alert Alert, err error)
}
