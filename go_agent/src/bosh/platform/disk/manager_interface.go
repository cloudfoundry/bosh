package disk

type Manager interface {
	GetPartitioner() Partitioner
	GetFormatter() Formatter
	GetMounter() Mounter
}
