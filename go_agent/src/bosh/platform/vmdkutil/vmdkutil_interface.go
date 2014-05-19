package vmdkutil

type VmdkUtil interface {
	GetFileContents(fileName string) (contents []byte, err error)
}
