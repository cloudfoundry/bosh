package infrastructure

type MetadataService interface {
	GetPublicKey() (string, error)
}
