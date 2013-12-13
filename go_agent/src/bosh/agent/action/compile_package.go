package action

import (
	boshcomp "bosh/agent/compiler"
	bosherr "bosh/errors"
)

type compilePackageAction struct {
	compiler boshcomp.Compiler
}

func newCompilePackage(compiler boshcomp.Compiler) (compilePackage compilePackageAction) {
	compilePackage.compiler = compiler
	return
}

func (a compilePackageAction) IsAsynchronous() bool {
	return true
}

func (a compilePackageAction) Run(blobId, sha1, name, version string, deps boshcomp.Dependencies) (val map[string]interface{}, err error) {
	pkg := boshcomp.Package{
		BlobstoreId: blobId,
		Name:        name,
		Sha1:        sha1,
		Version:     version,
	}

	uploadedBlobId, uploadedSha1, err := a.compiler.Compile(pkg, deps)
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
