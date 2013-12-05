package settings

type Provider struct {
	settings Settings
}

func NewProvider(settings Settings) (provider *Provider) {
	provider = new(Provider)
	provider.settings = settings
	return
}

type MbusSettings interface {
	GetAgentId() string
	GetMbusUrl() string
}

func (provider *Provider) GetAgentId() string {
	return provider.settings.AgentId
}

func (provider *Provider) GetMbusUrl() string {
	return provider.settings.Mbus
}
