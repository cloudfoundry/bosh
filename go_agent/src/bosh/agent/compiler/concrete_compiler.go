package compiler

import (
	"os"
	"path/filepath"

	boshbc "bosh/agent/applier/bundlecollection"
	boshmodels "bosh/agent/applier/models"
	boshpa "bosh/agent/applier/packageapplier"
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshcmd "bosh/platform/commands"
	boshsys "bosh/system"
)

type CompileDirProvider interface {
	CompileDir() string
}

type concreteCompiler struct {
	compressor         boshcmd.Compressor
	blobstore          boshblob.Blobstore
	fs                 boshsys.FileSystem
	runner             boshsys.CmdRunner
	compileDirProvider CompileDirProvider
	packageApplier     boshpa.PackageApplier
	packagesBc         boshbc.BundleCollection
}

func NewConcreteCompiler(
	compressor boshcmd.Compressor,
	blobstore boshblob.Blobstore,
	fs boshsys.FileSystem,
	runner boshsys.CmdRunner,
	compileDirProvider CompileDirProvider,
	packageApplier boshpa.PackageApplier,
	packagesBc boshbc.BundleCollection,
) (c concreteCompiler) {
	c.compressor = compressor
	c.blobstore = blobstore
	c.fs = fs
	c.runner = runner
	c.compileDirProvider = compileDirProvider
	c.packageApplier = packageApplier
	c.packagesBc = packagesBc
	return
}

func (c concreteCompiler) Compile(pkg Package, deps []boshmodels.Package) (string, string, error) {
	err := c.packageApplier.KeepOnly([]boshmodels.Package{})
	if err != nil {
		return "", "", bosherr.WrapError(err, "Removing packages")
	}

	for _, dep := range deps {
		err := c.packageApplier.Apply(dep)
		if err != nil {
			return "", "", bosherr.WrapError(err, "Installing dependent package: '%s'", dep.Name)
		}
	}

	compilePath := filepath.Join(c.compileDirProvider.CompileDir(), pkg.Name)
	err = c.fetchAndUncompress(pkg, compilePath)
	if err != nil {
		return "", "", bosherr.WrapError(err, "Fetching package %s", pkg.Name)
	}

	compiledPkg := boshmodels.Package{
		Name:    pkg.Name,
		Version: pkg.Version,
	}

	compiledPkgBundle, err := c.packagesBc.Get(compiledPkg)
	if err != nil {
		return "", "", bosherr.WrapError(err, "Getting bundle for new package")
	}

	_, installPath, err := compiledPkgBundle.InstallWithoutContents()
	if err != nil {
		return "", "", bosherr.WrapError(err, "Setting up new package bundle")
	}

	_, enablePath, err := compiledPkgBundle.Enable()
	if err != nil {
		return "", "", bosherr.WrapError(err, "Enabling new package bundle")
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

		_, _, _, err = c.runner.RunComplexCommand(command)
		if err != nil {
			return "", "", bosherr.WrapError(err, "Running packaging script")
		}
	}

	tmpPackageTar, err := c.compressor.CompressFilesInDir(installPath)
	if err != nil {
		return "", "", bosherr.WrapError(err, "Compressing compiled package")
	}

	defer c.compressor.CleanUp(tmpPackageTar)

	uploadedBlobID, sha1, err := c.blobstore.Create(tmpPackageTar)
	if err != nil {
		return "", "", bosherr.WrapError(err, "Uploading compiled package")
	}

	err = compiledPkgBundle.Disable()
	if err != nil {
		return "", "", bosherr.WrapError(err, "Disabling compiled package")
	}

	err = compiledPkgBundle.Uninstall()
	if err != nil {
		return "", "", bosherr.WrapError(err, "Uninstalling compiled package")
	}

	return uploadedBlobID, sha1, nil
}

func (c concreteCompiler) fetchAndUncompress(pkg Package, targetDir string) error {
	// Do not verify integrity of the download via SHA1
	// because Director might have stored non-matching SHA1.
	// This will be fixed in future by explicitly asking to verify SHA1
	// instead of doing that by default like all other downloads.
	// (Ruby agent mistakenly never checked SHA1.)
	depFilePath, err := c.blobstore.Get(pkg.BlobstoreID, "")
	if err != nil {
		return bosherr.WrapError(err, "Fetching package blob %s", pkg.BlobstoreID)
	}

	err = c.atomicDecompress(depFilePath, targetDir)
	if err != nil {
		return bosherr.WrapError(err, "Uncompressing package %s", pkg.Name)
	}

	return nil
}

func (c concreteCompiler) atomicDecompress(archivePath string, finalDir string) error {
	tmpInstallPath := finalDir + "-bosh-agent-unpack"

	{
		err := c.fs.RemoveAll(finalDir)
		if err != nil {
			return bosherr.WrapError(err, "Removing install path %s", finalDir)
		}

		err = c.fs.MkdirAll(finalDir, os.FileMode(0755))
		if err != nil {
			return bosherr.WrapError(err, "Creating install path %s", finalDir)
		}
	}

	{
		err := c.fs.RemoveAll(tmpInstallPath)
		if err != nil {
			return bosherr.WrapError(err, "Removing temporary compile directory %s", tmpInstallPath)
		}

		err = c.fs.MkdirAll(tmpInstallPath, os.FileMode(0755))
		if err != nil {
			return bosherr.WrapError(err, "Creating temporary compile directory %s", tmpInstallPath)
		}
	}

	err := c.compressor.DecompressFileToDir(archivePath, tmpInstallPath)
	if err != nil {
		return bosherr.WrapError(err, "Decompressing files from %s to %s", archivePath, tmpInstallPath)
	}

	err = c.fs.Rename(tmpInstallPath, finalDir)
	if err != nil {
		return bosherr.WrapError(err, "Moving temporary directory %s to final destination %s", tmpInstallPath, finalDir)
	}

	return nil
}
