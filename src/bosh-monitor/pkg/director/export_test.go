package director

// UaaCACertPath exposes the unexported uaaCACertPath method so external
// test packages can verify CA-cert selection logic without needing a live
// UAA server or TLS negotiation. Compiled only during test runs.
func UaaCACertPath(ap *AuthProvider) string {
	return ap.uaaCACertPath()
}
