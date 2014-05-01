package fakes

type FakeDNSResolver struct {
	LookupHostIP         string
	LookupHostDNSServers []string
	LookupHostHost       string
}

func (res *FakeDNSResolver) LookupHost(dnsServers []string, host string) (string, error) {
	res.LookupHostDNSServers = dnsServers
	res.LookupHostHost = host
	return res.LookupHostIP, nil
}
