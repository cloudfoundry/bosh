package infrastructure

type Infrastructure interface {
	GetPublicKey() (publicKey string, err error)
	GetSettings() (settings Settings, err error)
}
