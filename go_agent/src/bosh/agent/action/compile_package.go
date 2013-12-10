package action

import (
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshdisk "bosh/platform/disk"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"encoding/json"
	"os"
	"path/filepath"
)

type compilePackageAction struct {
	compressor boshdisk.Compressor
	blobstore  boshblob.Blobstore
	fs         boshsys.FileSystem
}

type Dependencies map[string]Dependency

type Dependency struct {
	BlobstoreId string `json:"blobstore_id"`
	Name        string `json:"name"`
	Sha1        string `json:"sha1"`
	Version     string `json:"version"`
}

func newCompilePackage(compressor boshdisk.Compressor, blobstore boshblob.Blobstore, fs boshsys.FileSystem) (compilePackage compilePackageAction) {
	compilePackage.compressor = compressor
	compilePackage.blobstore = blobstore
	compilePackage.fs = fs

	return
}

func (a compilePackageAction) IsAsynchronous() bool {
	return true
}

func (a compilePackageAction) Run(payloadBytes []byte) (value interface{}, err error) {
	var payload struct {
		Arguments []interface{}
	}
	err = json.Unmarshal(payloadBytes, &payload)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling payload")
		return
	}

	deps, err := getPackageDependencies(payload.Arguments[4])
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshaling dependencies")
		return
	}

	var depFile *os.File

	for _, dep := range deps {
		depFile, err = a.blobstore.Get(dep.BlobstoreId)
		if err != nil {
			return
		}
		depFilePath := filepath.Join(boshsettings.VCAP_PKG_DIR, dep.Name, dep.Version)
		a.compressor.DecompressFileToDir(depFile, depFilePath)
	}

	srcPkgFile, err := a.blobstore.Get(payload.Arguments[0].(string))

	compilePath := filepath.Join(boshsettings.VCAP_COMPILE_DIR, payload.Arguments[2].(string))
	a.fs.MkdirAll(compilePath, os.ModePerm)
	a.compressor.DecompressFileToDir(srcPkgFile, compilePath)

	return
}

func getPackageDependencies(dependencies interface{}) (deps Dependencies, err error) {
	depsJson, err := json.Marshal(dependencies)

	if err != nil {
		err = bosherr.WrapError(err, "Interpret compile package dependencies")
		return
	}

	err = json.Unmarshal(depsJson, &deps)

	if err != nil {
		err = bosherr.WrapError(err, "Unmarshal compile package dependencies")
		return
	}

	return
}

func getDependency(dependency interface{}) (dep Dependency, err error) {
	depJson, err := json.Marshal(dependency)

	if err != nil {
		err = bosherr.WrapError(err, "Interpret compile package dependencies")
		return
	}

	err = json.Unmarshal(depJson, &dep)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshal compile package dependencies")
		return
	}

	return
}
