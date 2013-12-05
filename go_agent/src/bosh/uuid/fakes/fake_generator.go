package fakes

type FakeGenerator struct {
	GeneratedUuid string
}

func (gen *FakeGenerator) Generate() (uuid string, err error) {
	return gen.GeneratedUuid, nil
}
