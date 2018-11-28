package certs

import (
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"gopkg.in/yaml.v2"

	bosherr "github.com/cloudfoundry/bosh-utils/errors"
	boshsys "github.com/cloudfoundry/bosh-utils/system"
)



func GetJobCertificates(path string, fs boshsys.FileSystem) (map[string]string, error) {
	if !fs.FileExists(path) {
		return nil, errors.New(fmt.Sprintf("File %s not found", path))
	}

	data, err := fs.ReadFile(path)

	if err != nil {
		return nil, bosherr.WrapError(err, "unable to read file")
	}

	jobCerts := make(map[string]string)
	err = yaml.Unmarshal(data, &jobCerts)
	if err != nil {
		return nil, bosherr.WrapError(err, fmt.Sprintf("Unmarshaling yml for %s file failed", path))
	}

	return jobCerts, nil
}

func GetCertExpiryDate(cert string) (int64, error) {
	block, _ := pem.Decode([]byte(cert))
	if block == nil {
		return 0, errors.New("failed to decode certificate")
	}

	parsedCert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return 0, bosherr.WrapError(err, "failed to parse certificate")
	}

	return parsedCert.NotAfter.Unix(), nil
}
