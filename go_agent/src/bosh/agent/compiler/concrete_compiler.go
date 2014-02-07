package compiler

import (
	boshbc "bosh/agent/applier/bundlecollection"
	boshmodels "bosh/agent/applier/models"
	boshpa "bosh/agent/applier/packageapplier"
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshcmd "bosh/platform/commands"
	boshdirs "bosh/settings/directories"
	boshsys "bosh/system"
	"os"
	"path/filepath"
)

type concreteCompiler struct {
	compressor     boshcmd.Compressor
	blobstore      boshblob.Blobstore
	fs             boshsys.FileSystem
	runner         boshsys.CmdRunner
	dirProvider    boshdirs.DirectoriesProvider
	packageApplier boshpa.PackageApplier
	packagesBc     boshbc.BundleCollection
}

func NewConcreteCompiler(
	compressor boshcmd.Compressor,
	blobstore boshblob.Blobstore,
	fs boshsys.FileSystem,
	runner boshsys.CmdRunner,
	dirProvider boshdirs.DirectoriesProvider,
	packageApplier boshpa.PackageApplier,
	packagesBc boshbc.BundleCollection,
) (c concreteCompiler) {

	c.compressor = compressor
	c.blobstore = blobstore
	c.fs = fs
	c.runner = runner
	c.dirProvider = dirProvider
	c.packageApplier = packageApplier
	c.packagesBc = packagesBc
	return
}

func (c concreteCompiler) Compile(pkg Package, deps []boshmodels.Package) (uploadedBlobId, sha1 string, err error) {
	for _, dep := range deps {
		err = c.packageApplier.Apply(dep)
		if err != nil {
			err = bosherr.WrapError(err, "Installing dependent package: '%s'", dep.Name)
			return
		}
	}

	compilePath := filepath.Join(c.dirProvider.CompileDir(), pkg.Name)
	err = c.fetchAndUncompress(pkg, compilePath)
	if err != nil {
		err = bosherr.WrapError(err, "Fetching package %s", pkg.Name)
		return
	}

	compiledPkg := boshmodels.Package{
		Name:    pkg.Name,
		Version: pkg.Version,
	}

	compiledPkgBundle, err := c.packagesBc.Get(compiledPkg)
	if err != nil {
		err = bosherr.WrapError(err, "Getting bundle for new package")
		return
	}

	_, installPath, err := compiledPkgBundle.Install()
	if err != nil {
		err = bosherr.WrapError(err, "setting up new package bundle")
		return
	}

	_, enablePath, err := compiledPkgBundle.Enable()
	if err != nil {
		err = bosherr.WrapError(err, "enabling new package bundle")
		return
	}

	scriptPath := filepath.Join(compilePath, "packaging")

	if c.fs.FileExists(scriptPath) {
		command := boshsys.Command{
			Name: "bash",
			Args: []string{"-x", "packaging"},
			Env: map[string]string{
				"BOSH_COMPILE_TARGET":  compilePath,
				"BOSH_INSTALL_TARGET":  enablePath,
				"BOSH_PACKAGE_NAME":    pkg.Name,
				"BOSH_PACKAGE_VERSION": pkg.Version,
			},
			WorkingDir: compilePath,
		}
		_, _, err = c.runner.RunComplexCommand(command)
		if err != nil {
			err = bosherr.WrapError(err, "Running packaging script")
			return
		}
	}

	tmpPackageTar, err := c.compressor.CompressFilesInDir(installPath)
	if err != nil {
		err = bosherr.WrapError(err, "Compressing compiled package")
		return
	}

	uploadedBlobId, sha1, err = c.blobstore.Create(tmpPackageTar)
	if err != nil {
		err = bosherr.WrapError(err, "Uploading compiled package")
	}

	err = compiledPkgBundle.Disable()
	if err != nil {
		err = bosherr.WrapError(err, "Disabling compiled package")
		return
	}

	err = compiledPkgBundle.Uninstall()
	if err != nil {
		err = bosherr.WrapError(err, "Uninstalling compiled package")
		return
	}

	return
}

func (c concreteCompiler) fetchAndUncompress(pkg Package, targetDir string) (err error) {
	depFilePath, err := c.blobstore.Get(pkg.BlobstoreId, pkg.Sha1)
	if err != nil {
		err = bosherr.WrapError(err, "Fetching package blob %s", pkg.BlobstoreId)
		return
	}

	c.fs.RemoveAll(targetDir)
	err = c.fs.MkdirAll(targetDir, os.FileMode(0755))
	if err != nil {
		err = bosherr.WrapError(err, "Cleaning package install path %s", targetDir)
		return
	}

	err = c.atomicDecompress(depFilePath, targetDir)
	if err != nil {
		err = bosherr.WrapError(err, "Uncompressing package %s", pkg.Name)
	}

	return
}

func (c concreteCompiler) atomicDecompress(archivePath string, finalDir string) (err error) {
	tmpInstallPath := finalDir + "-bosh-agent-unpack"
	c.fs.RemoveAll(tmpInstallPath)
	c.fs.MkdirAll(tmpInstallPath, os.FileMode(0755))

	err = c.compressor.DecompressFileToDir(archivePath, tmpInstallPath)
	if err != nil {
		err = bosherr.WrapError(err, "Decompressing files from %s to %s", archivePath, tmpInstallPath)
		return
	}

	err = c.fs.Rename(tmpInstallPath, finalDir)
	if err != nil {
		err = bosherr.WrapError(err, "Moving temporary directory %s to final destination %s", tmpInstallPath, finalDir)
	}
	return
}
