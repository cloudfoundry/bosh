package agent

type Infrastructure interface {
	GetPublicKey() (publicKey string, err error)
}
