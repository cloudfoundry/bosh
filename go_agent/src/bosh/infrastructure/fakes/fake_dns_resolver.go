package fakes

import (
	"fmt"
	"reflect"
)

type FakeDNSResolver struct {
	records []FakeDNSRecord

	LookupHostErr error
}

type FakeDNSRecord struct {
	DNSServers []string
	Host       string
	IP         string
}

func (res *FakeDNSResolver) RegisterRecord(record FakeDNSRecord) {
	res.records = append(res.records, record)
}

func (res *FakeDNSResolver) LookupHost(dnsServers []string, host string) (string, error) {
	if res.LookupHostErr != nil {
		return "", res.LookupHostErr
	}

	for _, record := range res.records {
		if reflect.DeepEqual(record.DNSServers, dnsServers) && record.Host == host {
			return record.IP, nil
		}
	}

	panic(fmt.Sprintf("Failed to find DNS record for host %s in %#v", host, res.records))
}
