package cdutil

type CdUtil interface {
	GetFileContents(fileName string) (contents []byte, err error)
}
