package certs

import (
	"fmt"
	"os"

	boshsys "github.com/cloudfoundry/bosh-utils/system"
)

// func that returns the paths for every validate_certificate.yml
func GetCredsPaths(fs boshsys.FileSystem, jobsDir string) []string {
	results := make([]string, 0)

	_ = fs.Walk(jobsDir, func(path string, info os.FileInfo, err error) error {
		certsFilePath := fmt.Sprintf("%s/%s", path, CERTS_FILE_NAME)

		if fs.FileExists(certsFilePath) && info.IsDir() {
			results = append(results, certsFilePath)
		}

		return nil
	})
	return results
}
