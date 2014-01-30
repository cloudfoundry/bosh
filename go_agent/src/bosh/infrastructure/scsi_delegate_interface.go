package infrastructure

type ScsiDelegate interface {
	RescanScsiBus()
}
