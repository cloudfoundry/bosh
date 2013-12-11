package action

import (
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
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
	platform   boshplatform.Platform
}

type Dependencies map[string]Dependency

type Dependency struct {
	BlobstoreId string `json:"blobstore_id"`
	Name        string
	Sha1        string
	Version     string
}

func newCompilePackage(c boshdisk.Compressor, b boshblob.Blobstore, p boshplatform.Platform) (cPkg compilePackageAction) {
	cPkg.compressor = c
	cPkg.blobstore = b
	cPkg.fs = p.GetFs()
	cPkg.platform = p

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

	blobstoreId := payload.Arguments[0].(string)
	sha1 := payload.Arguments[1].(string)
	pkgName := payload.Arguments[2].(string)
	pkgVersion := payload.Arguments[3].(string)

	return a.run(blobstoreId, sha1, pkgName, pkgVersion, deps)
}

func (a compilePackageAction) run(bstoreId, sha1, pName, pVer string, deps Dependencies) (val interface{}, err error) {
	var depFile *os.File

	for _, dep := range deps {
		depFile, err = a.blobstore.Get(dep.BlobstoreId)
		if err != nil {
			err = bosherr.WrapError(err, "Fetching dependent package blob %s", bstoreId)
			return
		}

		depFilePath := packageInstallPath(dep.Name, dep.Version)
		err = cleanPackageInstallPath(depFilePath, a.fs)
		if err != nil {
			err = bosherr.WrapError(err, "Clean package install path %s", depFilePath)
			return
		}
		err = a.atomicDecompress(depFile, depFilePath)
		if err != nil {
			err = bosherr.WrapError(err, "Uncompressing dependent package %", dep.Name)
			return
		}
	}

	srcPkgFile, err := a.blobstore.Get(bstoreId)
	if err != nil {
		err = bosherr.WrapError(err, "Fetching source package blob %s", bstoreId)
		return
	}

	compilePath := filepath.Join(boshsettings.VCAP_COMPILE_DIR, pName)
	a.fs.MkdirAll(compilePath, os.ModePerm)

	err = a.atomicDecompress(srcPkgFile, compilePath)
	if err != nil {
		err = bosherr.WrapError(err, "Uncompressing source package %s", pName)
	}

	installPath := packageInstallPath(pName, pVer)
	err = cleanPackageInstallPath(installPath, a.fs)
	if err != nil {
		err = bosherr.WrapError(err, "Clean package install path %s", installPath)
		return
	}

	packageLinkPath := filepath.Join(boshsettings.VCAP_BASE_DIR, "packages", pName)
	err = a.fs.Symlink(installPath, packageLinkPath)
	if err != nil {
		err = bosherr.WrapError(err, "Symlinking %s to %s", installPath, packageLinkPath)
	}

	manageEnvironmentVariables(compilePath, packageLinkPath, pName, pVer)

	scriptPath := filepath.Join(compilePath, "packaging")

	if a.fs.FileExists(scriptPath) {
		_, _, err = a.platform.GetRunner().RunCommand(
			"cd", compilePath, "&&",
			"bash", "-x", "packaging", "2>&1")
		if err != nil {
			err = bosherr.WrapError(err, "Running packaging script")
			return
		}
	}

	return
}

func (a compilePackageAction) atomicDecompress(archive *os.File, finalDir string) (err error) {
	tmpInstallPath := finalDir + "-bosh-agent-unpack"
	a.fs.RemoveAll(tmpInstallPath)
	a.fs.MkdirAll(tmpInstallPath, os.ModePerm)

	err = a.compressor.DecompressFileToDir(archive, tmpInstallPath)
	if err != nil {
		return
	}

	err = a.fs.Rename(tmpInstallPath, finalDir)

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

func cleanPackageInstallPath(installPath string, fs boshsys.FileSystem) (err error) {
	fs.RemoveAll(installPath)
	err = fs.MkdirAll(installPath, os.FileMode(0700))

	return
}

func packageInstallPath(packageName string, packageVersion string) string {
	return filepath.Join(boshsettings.VCAP_PKG_DIR, packageName, packageVersion)
}

func manageEnvironmentVariables(compileTarget, installTarget, pkgName, pkgVersion string) {
	os.Setenv("BOSH_COMPILE_TARGET", compileTarget)
	os.Setenv("BOSH_INSTALL_TARGET", installTarget)
	os.Setenv("BOSH_PACKAGE_NAME", pkgName)
	os.Setenv("BOSH_PACKAGE_VERSION", pkgVersion)

	os.Setenv("GEM_HOME", "")
	os.Setenv("BUNDLE_GEMFILE", "")
	os.Setenv("RUBYOPT", "")
}
