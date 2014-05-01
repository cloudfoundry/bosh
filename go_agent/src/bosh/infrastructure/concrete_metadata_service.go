package infrastructure

import (
	"fmt"
	"io/ioutil"
	"net/http"

	bosherr "bosh/errors"
)

type concreteMetadataService struct {
	metadataHost string
}

func NewConcreteMetadataService(metadataHost string) concreteMetadataService {
	return concreteMetadataService{metadataHost: metadataHost}
}

func (ms concreteMetadataService) GetPublicKey() (string, error) {
	url := fmt.Sprintf("%s/latest/meta-data/public-keys/0/openssh-key", ms.metadataHost)

	resp, err := http.Get(url)
	if err != nil {
		return "", bosherr.WrapError(err, "Getting open ssh key")
	}

	defer resp.Body.Close()

	keyBytes, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", bosherr.WrapError(err, "Reading ssh key response body")
	}

	return string(keyBytes), nil
}
