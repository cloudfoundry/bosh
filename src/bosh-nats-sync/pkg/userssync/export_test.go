package userssync

import (
	"crypto/tls"
	"net/http"
)

// IsConnectionError exposes isConnectionError for use in external test packages.
// This file is compiled only during test runs.
var IsConnectionError = isConnectionError

// BuildDirectorTLSConfig exposes the *tls.Config built from director_ca_cert so
// external tests can assert the "use system trust store" (RootCAs nil, no
// error) vs "fail loudly" (error) behavior without reaching into the internals
// of buildHTTPClient.
func (u *UsersSync) BuildDirectorTLSConfig() (*tls.Config, error) {
	client, err := u.buildHTTPClient()
	if err != nil {
		return nil, err
	}
	return client.Transport.(*http.Transport).TLSClientConfig, nil
}
