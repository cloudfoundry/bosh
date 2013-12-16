package action

import (
	bosherr "bosh/errors"
	boshsettings "bosh/settings"
	"encoding/json"
)

type diskParams struct {
	settings boshsettings.Service
	payload  diskPayloadType
}

type diskPayloadType struct {
	Arguments []string
}

func NewDiskParams(settings boshsettings.Service, payloadBytes []byte) (p diskParams, err error) {
	p.settings = settings

	err = json.Unmarshal(payloadBytes, &p.payload)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling disk payload")
		return
	}
	return
}

func (p diskParams) GetDevicePath() (devicePath string, err error) {
	if len(p.payload.Arguments) != 1 {
		err = bosherr.New("Invalid payload missing volume id.")
		return
	}

	volumeId := p.payload.Arguments[0]
	disks := p.settings.GetDisks()
	devicePath, found := disks.Persistent[volumeId]
	if !found {
		err = bosherr.New("Invalid payload volume id does not match")
	}
	return
}
