package infrastructure

type dnsResolver interface {
	LookupHost(dnsServers []string, host string) (ip string, err error)
}
