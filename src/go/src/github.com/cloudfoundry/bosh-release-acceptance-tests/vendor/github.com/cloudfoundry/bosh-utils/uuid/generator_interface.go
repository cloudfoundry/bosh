package uuid

type Generator interface {
	Generate() (uuid string, err error)
}
