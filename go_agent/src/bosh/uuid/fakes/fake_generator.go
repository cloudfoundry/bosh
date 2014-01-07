package fakes

type FakeGenerator struct {
	GeneratedUuid string
	GenerateError error
}

func (gen *FakeGenerator) Generate() (uuid string, err error) {
	return gen.GeneratedUuid, gen.GenerateError
}
