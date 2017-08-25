package auth

import (
	"github.com/nats-io/gnatsd/server"
)

type CertificateAuth struct {
	certificateClients map[string]*server.CertificateClient
	legacyAuth         server.Auth
}

func NewCertificateAuth(certificateClients []*server.CertificateClient, legacyAuth server.Auth) *CertificateAuth {
	certificateAuth := &CertificateAuth{
		certificateClients: make(map[string]*server.CertificateClient),
		legacyAuth: legacyAuth,
	}
	for _, client := range certificateClients {
		certificateAuth.certificateClients[client.ClientName] = client
	}
	return certificateAuth
}

func (a *CertificateAuth) Check(c server.ClientAuth) bool {
	if c.IsLegacyBoshClient() {
		if c.GetOpts().Username == "" {
			return false
		}

		return a.legacyAuth.Check(c)
	} else {
		clientName, clientID, err := c.GetCertificateClientNameAndID()

		if err != nil {
			server.Errorf("Unable to determine client name and id: %s", err.Error())
			return false
		}

		if clientName == "" {
			return false
		}

		client, ok := a.certificateClients[clientName]
		if !ok {
			return false
		}

		c.RegisterCertificateClient(client, clientID)
		return true
	}
}
