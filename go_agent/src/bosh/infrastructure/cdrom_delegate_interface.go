package infrastructure

type CDROMDelegate interface {
	GetFileContentsFromCDROM(filePath string) (contents []byte, err error)
}
