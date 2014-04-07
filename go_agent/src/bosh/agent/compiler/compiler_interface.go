package compiler

import (
	boshmodels "bosh/agent/applier/models"
)

type Compiler interface {
	Compile(pkg Package, deps []boshmodels.Package) (blobID, sha1 string, err error)
}

type Package struct {
	BlobstoreID string `json:"blobstore_id"`
	Name        string
	Sha1        string
	Version     string
}

type Dependencies map[string]Package
