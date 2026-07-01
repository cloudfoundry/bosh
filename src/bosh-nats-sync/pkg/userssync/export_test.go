package userssync

import "crypto/x509"

// IsConnectionError exposes isConnectionError for use in external test packages.
// This file is compiled only during test runs.
var IsConnectionError = isConnectionError

// DirectorCACertPool exposes directorCACertPool so external tests can assert the
// "use system trust store" (nil pool, nil error) vs "fail loudly" (error)
// behavior for a configured director_ca_cert.
func (u *UsersSync) DirectorCACertPool() (*x509.CertPool, error) {
	return u.directorCACertPool()
}
