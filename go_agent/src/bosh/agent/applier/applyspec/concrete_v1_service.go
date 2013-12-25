package applyspec

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"encoding/json"
)

type concreteV1Service struct {
	specFilePath string
	fs           boshsys.FileSystem
}

func NewConcreteV1Service(fs boshsys.FileSystem, specFilePath string) (service concreteV1Service) {
	service.fs = fs
	service.specFilePath = specFilePath
	return
}

func (s concreteV1Service) Get() (spec V1ApplySpec, err error) {
	contents, err := s.fs.ReadFile(s.specFilePath)
	if err != nil {
		err = bosherr.WrapError(err, "Reading json spec file")
		return
	}

	err = json.Unmarshal([]byte(contents), &spec)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling json spec file")
		return
	}

	return
}

func (s concreteV1Service) Set(spec V1ApplySpec) (err error) {
	specBytes, err := json.Marshal(spec)
	if err != nil {
		err = bosherr.WrapError(err, "Marshalling apply spec")
		return
	}

	_, err = s.fs.WriteToFile(s.specFilePath, string(specBytes))
	if err != nil {
		err = bosherr.WrapError(err, "Writing spec to disk")
	}
	return
}
