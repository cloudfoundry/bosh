package certs

import (
	boshsys "github.com/cloudfoundry/bosh-utils/system"
)

type CertExpirationInfo struct {
	Expires      int64  `json:"expires"`
	ErrorString  string `json:"error_string"`
}

type CertsInfo struct {
	Certificates map[string]CertExpirationInfo `json:"certificates"`
	ErrorString string `json:"error_string"`
}

const (
	BASE_JOB_DIR = "var/vcap/jobs"
	CONFIG_DIR = "config"
	CERTS_FILE_NAME = "validate_certificate.yml"
)

func GetCertificateExpiryDates(fs boshsys.FileSystem) interface{} {
	certsInfo := make(map[string]CertsInfo)

	certificatePaths := GetCredsPaths(fs, BASE_JOB_DIR)

	for _, path := range certificatePaths {
		fileCerts := make(map[string]CertExpirationInfo)
		errorMessage := ""

		properties, err := GetJobCertificates(path, fs)
		if err != nil {
			errorMessage = err.Error()
		} else {
			for propertyName, cert := range properties {
				certExpirationInfo := CertExpirationInfo{}

				expiryDate, err := GetCertExpiryDate(cert)
				if err != nil {
					certExpirationInfo.ErrorString = err.Error()
				}

				certExpirationInfo.Expires = expiryDate

				fileCerts[propertyName] = certExpirationInfo
			}
		}

		certsInfo[path] = CertsInfo{
			Certificates: fileCerts,
			ErrorString: errorMessage,
		}
	}
	return certsInfo
}