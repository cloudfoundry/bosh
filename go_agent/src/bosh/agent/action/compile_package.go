package action

import (
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshcmd "bosh/platform/commands"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"os"
	"path/filepath"
)

type compilePackageAction struct {
	compressor boshcmd.Compressor
	blobstore  boshblob.Blobstore
	fs         boshsys.FileSystem
	platform   boshplatform.Platform
}

type Dependencies map[string]Package

type Package struct {
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

func (a compilePackageAction) Run(blobId, sha1, name, version string, deps Dependencies) (val map[string]interface{}, err error) {
	pkg := Package{
		BlobstoreId: blobId,
		Name:        name,
		Sha1:        sha1,
		Version:     version,
	}

	for _, dep := range deps {
		targetDir := packageInstallPath(dep)

		err = a.fetchAndUncompress(dep, targetDir)
		if err != nil {
			err = bosherr.WrapError(err, "Fetching dependency %s", dep.Name)
			return
		}
	}

	compilePath := filepath.Join(boshsettings.VCAP_COMPILE_DIR, pkg.Name)
	err = a.fetchAndUncompress(pkg, compilePath)
	if err != nil {
		err = bosherr.WrapError(err, "Fetching package %s", pkg.Name)
		return
	}

	installPath := packageInstallPath(pkg)
	err = cleanPackageInstallPath(installPath, a.fs)
	if err != nil {
		err = bosherr.WrapError(err, "Clean package install path %s", installPath)
		return
	}

	packageLinkPath := filepath.Join(boshsettings.VCAP_BASE_DIR, "packages", pkg.Name)
	err = a.fs.Symlink(installPath, packageLinkPath)
	if err != nil {
		err = bosherr.WrapError(err, "Symlinking %s to %s", installPath, packageLinkPath)
		return
	}

	scriptPath := filepath.Join(compilePath, "packaging")

	if a.fs.FileExists(scriptPath) {
		command := boshsys.Command{
			Name: "bash",
			Args: []string{"-x", "packaging"},
			Env: map[string]string{
				"BOSH_COMPILE_TARGET":  compilePath,
				"BOSH_INSTALL_TARGET":  installPath,
				"BOSH_PACKAGE_NAME":    name,
				"BOSH_PACKAGE_VERSION": version,
			},
			WorkingDir: compilePath,
		}
		_, _, err = a.platform.GetRunner().RunComplexCommand(command)
		if err != nil {
			err = bosherr.WrapError(err, "Running packaging script")
			return
		}
	}

	tmpPackageTar, err := a.compressor.CompressFilesInDir(installPath, []string{"**/*"})
	if err != nil {
		err = bosherr.WrapError(err, "Compressing compiled package")
		return
	}

	uploadedBlobId, err := a.blobstore.Create(tmpPackageTar)
	if err != nil {
		err = bosherr.WrapError(err, "Uploading compiled package")
		return
	}

	result := map[string]string{
		"blobstore_id": uploadedBlobId,
	}

	val = map[string]interface{}{
		"result": result,
	}
	return
}

func (a compilePackageAction) fetchAndUncompress(pkg Package, targetDir string) (err error) {
	depFilePath, err := a.blobstore.Get(pkg.BlobstoreId)
	if err != nil {
		err = bosherr.WrapError(err, "Fetching package blob %s", pkg.BlobstoreId)
		return
	}

	err = cleanPackageInstallPath(targetDir, a.fs)
	if err != nil {
		err = bosherr.WrapError(err, "Cleaning package install path %s", targetDir)
		return
	}

	err = a.atomicDecompress(depFilePath, targetDir)
	if err != nil {
		err = bosherr.WrapError(err, "Uncompressing package %s", pkg.Name)
	}

	return
}

func (a compilePackageAction) atomicDecompress(archivePath string, finalDir string) (err error) {
	tmpInstallPath := finalDir + "-bosh-agent-unpack"
	a.fs.RemoveAll(tmpInstallPath)
	a.fs.MkdirAll(tmpInstallPath, os.FileMode(0700))

	err = a.compressor.DecompressFileToDir(archivePath, tmpInstallPath)
	if err != nil {
		err = bosherr.WrapError(err, "Decompressing files from %s to %s", archivePath, tmpInstallPath)
		return
	}

	err = a.fs.Rename(tmpInstallPath, finalDir)
	if err != nil {
		err = bosherr.WrapError(err, "Moving temporary directory %s to final destination %s", tmpInstallPath, finalDir)
	}
	return
}

func cleanPackageInstallPath(installPath string, fs boshsys.FileSystem) (err error) {
	fs.RemoveAll(installPath)
	err = fs.MkdirAll(installPath, os.FileMode(0700))

	return
}

func packageInstallPath(dep Package) string {
	return filepath.Join(boshsettings.VCAP_PKG_DIR, dep.Name, dep.Version)
}
