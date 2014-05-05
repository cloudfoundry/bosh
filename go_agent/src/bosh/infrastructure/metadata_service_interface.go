package infrastructure

type MetadataService interface {
	GetPublicKey() (string, error)
	GetInstanceID() (string, error)
	GetServerName() (string, error)
	GetRegistryEndpoint() (string, error)
}
