package action

import (
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshcmd "bosh/platform/commands"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"encoding/json"
	"os"
	"path/filepath"
)

type compilePackageAction struct {
	compressor boshcmd.Compressor
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

func newCompilePackage(compressor boshcmd.Compressor, blobstore boshblob.Blobstore, p boshplatform.Platform) (compilePackage compilePackageAction) {
	compilePackage.compressor = compressor
	compilePackage.blobstore = blobstore
	compilePackage.fs = p.GetFs()
	compilePackage.platform = p

	return
}

func (a compilePackageAction) IsAsynchronous() bool {
	return true
}

func (a compilePackageAction) Run(bstoreId, sha1, pName, pVer string, deps Dependencies) (val interface{}, err error) {
	var depFilePath string

	for _, dep := range deps {
		depFilePath, err = a.blobstore.Get(dep.BlobstoreId)
		if err != nil {
			err = bosherr.WrapError(err, "Fetching dependent package blob %s", bstoreId)
			return
		}

		targetDir := packageInstallPath(dep.Name, dep.Version)
		err = cleanPackageInstallPath(targetDir, a.fs)
		if err != nil {
			err = bosherr.WrapError(err, "Clean package install path %s", targetDir)
			return
		}
		err = a.atomicDecompress(depFilePath, targetDir)
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

	tmpPackageTar, err := a.compressor.CompressFilesInDir(installPath, []string{"**/*"})
	if err != nil {
		bosherr.WrapError(err, "Compressing compiled package")
		return
	}

	uploadedBlobId, err := a.blobstore.Create(tmpPackageTar)
	if err != nil {
		bosherr.WrapError(err, "Uploading compiled package")
		return
	}

	v := make(map[string]interface{})
	result := make(map[string]string)

	result["blobstore_id"] = uploadedBlobId
	v["result"] = result

	val = v
	return
}

func (a compilePackageAction) atomicDecompress(archivePath string, finalDir string) (err error) {
	tmpInstallPath := finalDir + "-bosh-agent-unpack"
	a.fs.RemoveAll(tmpInstallPath)
	a.fs.MkdirAll(tmpInstallPath, os.ModePerm)

	err = a.compressor.DecompressFileToDir(archivePath, tmpInstallPath)
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
