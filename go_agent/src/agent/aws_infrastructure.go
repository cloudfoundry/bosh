package agent

import (
	"fmt"
	"io/ioutil"
	"net/http"
)

type awsInfrastructure struct {
	metadataHost string
}

func NewAwsInfrastructure(metadataHost string) (infrastructure Infrastructure) {
	return awsInfrastructure{
		metadataHost: metadataHost,
	}
}

func (inf awsInfrastructure) GetPublicKey() (publicKey string, err error) {
	url := fmt.Sprintf("%s/latest/meta-data/public-keys/0/openssh-key", inf.metadataHost)

	resp, err := http.Get(url)
	if err != nil {
		return
	}
	defer resp.Body.Close()

	keyBytes, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return
	}

	publicKey = string(keyBytes)
	return
}
