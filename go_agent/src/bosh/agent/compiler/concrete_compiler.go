package compiler

import (
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshcmd "bosh/platform/commands"
	boshdirs "bosh/settings/directories"
	boshsys "bosh/system"
	"os"
	"path/filepath"
)

type concreteCompiler struct {
	compressor  boshcmd.Compressor
	blobstore   boshblob.Blobstore
	fs          boshsys.FileSystem
	runner      boshsys.CmdRunner
	dirProvider boshdirs.DirectoriesProvider
}

func newConcreteCompiler(
	compressor boshcmd.Compressor,
	blobstore boshblob.Blobstore,
	fs boshsys.FileSystem,
	runner boshsys.CmdRunner,
	dirProvider boshdirs.DirectoriesProvider,
) (c concreteCompiler) {

	c.compressor = compressor
	c.blobstore = blobstore
	c.fs = fs
	c.runner = runner
	c.dirProvider = dirProvider
	return
}

func (c concreteCompiler) Compile(pkg Package, deps Dependencies) (uploadedBlobId, sha1 string, err error) {
	for _, dep := range deps {
		targetDir := c.packageInstallPath(dep)

		err = c.fetchAndUncompress(dep, targetDir)
		if err != nil {
			err = bosherr.WrapError(err, "Fetching dependency %s", dep.Name)
			return
		}
	}

	compilePath := filepath.Join(c.dirProvider.CompileDir(), pkg.Name)
	err = c.fetchAndUncompress(pkg, compilePath)
	if err != nil {
		err = bosherr.WrapError(err, "Fetching package %s", pkg.Name)
		return
	}

	installPath := c.packageInstallPath(pkg)
	err = c.cleanPackageInstallPath(installPath)
	if err != nil {
		err = bosherr.WrapError(err, "Clean package install path %s", installPath)
		return
	}

	packageLinkPath := filepath.Join(c.dirProvider.BaseDir(), "packages", pkg.Name)
	err = c.fs.Symlink(installPath, packageLinkPath)
	if err != nil {
		err = bosherr.WrapError(err, "Symlinking %s to %s", installPath, packageLinkPath)
		return
	}

	scriptPath := filepath.Join(compilePath, "packaging")

	if c.fs.FileExists(scriptPath) {
		command := boshsys.Command{
			Name: "bash",
			Args: []string{"-x", "packaging"},
			Env: map[string]string{
				"BOSH_COMPILE_TARGET":  compilePath,
				"BOSH_INSTALL_TARGET":  installPath,
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
	return
}

func (c concreteCompiler) fetchAndUncompress(pkg Package, targetDir string) (err error) {
	depFilePath, err := c.blobstore.Get(pkg.BlobstoreId, pkg.Sha1)
	if err != nil {
		err = bosherr.WrapError(err, "Fetching package blob %s", pkg.BlobstoreId)
		return
	}

	err = c.cleanPackageInstallPath(targetDir)
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

func (c concreteCompiler) cleanPackageInstallPath(installPath string) (err error) {
	c.fs.RemoveAll(installPath)
	err = c.fs.MkdirAll(installPath, os.FileMode(0755))

	return
}

func (c concreteCompiler) packageInstallPath(dep Package) string {
	return filepath.Join(c.dirProvider.PkgDir(), dep.Name, dep.Version)
}
