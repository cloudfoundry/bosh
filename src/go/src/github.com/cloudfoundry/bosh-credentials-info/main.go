package main

import (
	"encoding/json"
	"fmt"
	"github.com/cloudfoundry/bosh-credentials-info/creds"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	"github.com/cloudfoundry/bosh-utils/system"
)

func main() {
	logger := boshlog.NewLogger(boshlog.LevelNone)
	fs := system.NewOsFileSystem(logger)

	output := creds.GetCertificateExpiryDates(fs)

	marshalled, _ := json.Marshal(output)


	fmt.Println(string(marshalled))
}
