package uuid

import (
	bosherr "github.com/cloudfoundry/bosh-utils/errors"
	gouuid "github.com/nu7hatch/gouuid"
)

type uuidV4Generator struct {
}

func NewGenerator() (gen Generator) {
	return uuidV4Generator{}
}

func (gen uuidV4Generator) Generate() (uuidStr string, err error) {
	uuid, err := gouuid.NewV4()
	if err != nil {
		err = bosherr.WrapError(err, "Generating V4 uuid")
		return
	}

	uuidStr = uuid.String()
	return
}
