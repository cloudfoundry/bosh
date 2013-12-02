package uuid

import gouuid "github.com/nu7hatch/gouuid"

type uuidV4Generator struct {
}

func NewGenerator() (gen Generator) {
	return uuidV4Generator{}
}

func (gen uuidV4Generator) Generate() (uuidStr string, err error) {
	uuid, err := gouuid.NewV4()
	if err != nil {
		return
	}

	uuidStr = uuid.String()
	return
}
