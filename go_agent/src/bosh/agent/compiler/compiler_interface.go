package compiler

type Compiler interface {
	Compile(pkg Package, deps Dependencies) (blobId, sha1 string, err error)
}

type Package struct {
	BlobstoreId string `json:"blobstore_id"`
	Name        string
	Sha1        string
	Version     string
}

type Dependencies map[string]Package
