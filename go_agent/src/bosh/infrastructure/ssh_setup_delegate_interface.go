package infrastructure

type SshSetupDelegate interface {
	SetupSsh(publicKey, username string) (err error)
}
