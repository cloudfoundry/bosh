package action

import (
	boshmodels "bosh/agent/applier/models"
	boshcomp "bosh/agent/compiler"
	bosherr "bosh/errors"
)

type CompilePackageAction struct {
	compiler boshcomp.Compiler
}

func NewCompilePackage(compiler boshcomp.Compiler) (compilePackage CompilePackageAction) {
	compilePackage.compiler = compiler
	return
}

func (a CompilePackageAction) IsAsynchronous() bool {
	return true
}

func (a CompilePackageAction) Run(blobId, sha1, name, version string, deps boshcomp.Dependencies) (val map[string]interface{}, err error) {
	pkg := boshcomp.Package{
		BlobstoreId: blobId,
		Name:        name,
		Sha1:        sha1,
		Version:     version,
	}

	modelsDeps := []boshmodels.Package{}

	for _, dep := range deps {
		modelsDeps = append(modelsDeps, boshmodels.Package{
			Name:    dep.Name,
			Version: dep.Version,
			Source: boshmodels.Source{
				Sha1:        dep.Sha1,
				BlobstoreId: dep.BlobstoreId,
			},
		})
	}

	uploadedBlobId, uploadedSha1, err := a.compiler.Compile(pkg, modelsDeps)
	if err != nil {
		err = bosherr.WrapError(err, "Compiling package %s", pkg.Name)
		return
	}

	result := map[string]string{
		"blobstore_id": uploadedBlobId,
		"sha1":         uploadedSha1,
	}

	val = map[string]interface{}{
		"result": result,
	}
	return
}
