package applyspec

import models "bosh/agent/applyspec/models"

type PackageSpec struct {
	Name        string `json:"name"`
	Version     string `json:"version"`
	Sha1        string `json:"sha1"`
	BlobstoreId string `json:"blobstore_id"`
}

func (s *PackageSpec) AsPackage() models.Package {
	return models.Package{
		Name:        s.Name,
		Version:     s.Version,
		Sha1:        s.Sha1,
		BlobstoreId: s.BlobstoreId,
	}
}
