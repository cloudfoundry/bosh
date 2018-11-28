package main

import (
	"encoding/json"
	"fmt"
	"github.com/cloudfoundry/bosh-credentials-info/certs"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	"github.com/cloudfoundry/bosh-utils/system"
)

func main() {
	logger := boshlog.NewLogger(boshlog.LevelNone)
	fs := system.NewOsFileSystem(logger)

	output := certs.GetCertificateExpiryDates(fs)

	marshaled, _ := json.Marshal(output)

	fmt.Println(string(marshaled))
}
