package settings

type DefaultNetworkDelegate interface {
	GetDefaultNetwork() (Network, error)
}
