package server

import (
	"bytes"
	"fmt"
)

const (
	TLS_CLIENT_HELLO = 1
	MIN_HEADER_SIZE = 6
)

// http://blog.fourthbit.com/2014/12/23/traffic-analysis-of-an-ssl-slash-tls-session
var tlsVersions = [][]byte{
	{22, 3, 1},
	{22, 3, 2},
	{22, 3, 3},
}

type TLSDetector struct{}

func (d TLSDetector) Detect(hdr []byte) (bool, error) {
	if len(hdr) < MIN_HEADER_SIZE {
		return false, fmt.Errorf("Expected header size to be %d, but was %d", MIN_HEADER_SIZE, len(hdr))
	}

	for _, sig := range tlsVersions {
		if bytes.HasPrefix(hdr, sig) {
			// https://tools.ietf.org/html/rfc5246#section-7.4.1.2
			if hdr[5] == TLS_CLIENT_HELLO {
				return true, nil
			}
		}
	}
	return false, nil
}
