package infrastructure

type FakeInfrastructure struct {
	PublicKey string
}

func (i *FakeInfrastructure) GetPublicKey() (publicKey string, err error) {
	publicKey = i.PublicKey
	return
}
