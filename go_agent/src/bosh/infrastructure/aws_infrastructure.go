package infrastructure

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
)

type awsInfrastructure struct {
	metadataHost string
}

func newAwsInfrastructure(metadataHost string) (infrastructure Infrastructure) {
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

func (inf awsInfrastructure) GetSettings() (settings Settings, err error) {
	userData, err := inf.getUserData()
	if err != nil {
		return
	}

	instanceId, err := inf.getInstanceId()
	if err != nil {
		return
	}

	settingsUrl := fmt.Sprintf("%s/instances/%s/settings", userData.Registry.Endpoint, instanceId)

	settingsResp, err := http.Get(settingsUrl)
	if err != nil {
		return
	}
	defer settingsResp.Body.Close()

	settingsBytes, err := ioutil.ReadAll(settingsResp.Body)
	if err != nil {
		return
	}

	err = json.Unmarshal(settingsBytes, &settings)
	return
}

type userDataType struct {
	Registry struct {
		Endpoint string
	}
}

func (inf awsInfrastructure) getUserData() (userData userDataType, err error) {
	userDataUrl := fmt.Sprintf("%s/latest/user-data", inf.metadataHost)

	userDataResp, err := http.Get(userDataUrl)
	if err != nil {
		return
	}
	defer userDataResp.Body.Close()

	userDataBytes, err := ioutil.ReadAll(userDataResp.Body)
	if err != nil {
		return
	}

	err = json.Unmarshal(userDataBytes, &userData)
	return
}

func (inf awsInfrastructure) getInstanceId() (instanceId string, err error) {
	instanceIdUrl := fmt.Sprintf("%s/latest/meta-data/instance-id", inf.metadataHost)
	instanceIdResp, err := http.Get(instanceIdUrl)
	if err != nil {
		return
	}
	defer instanceIdResp.Body.Close()

	instanceIdBytes, err := ioutil.ReadAll(instanceIdResp.Body)
	if err != nil {
		return
	}

	instanceId = string(instanceIdBytes)
	return
}
