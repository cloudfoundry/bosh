package jobapplier

import (
	bc "bosh/agent/applier/bundlecollection"
	models "bosh/agent/applier/models"
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshdisk "bosh/platform/disk"
	"os"
	"path/filepath"
)

type renderedJobApplier struct {
	jobsBc     bc.BundleCollection
	blobstore  boshblob.Blobstore
	compressor boshdisk.Compressor
}

func NewRenderedJobApplier(
	jobsBc bc.BundleCollection,
	blobstore boshblob.Blobstore,
	compressor boshdisk.Compressor,
) *renderedJobApplier {
	return &renderedJobApplier{
		jobsBc:     jobsBc,
		blobstore:  blobstore,
		compressor: compressor,
	}
}

func (s *renderedJobApplier) Apply(job models.Job) (err error) {
	fs, jobDir, err := s.jobsBc.Install(job)
	if err != nil {
		err = bosherr.WrapError(err, "Installing jobs bundle collection")
		return
	}

	file, err := s.blobstore.Get(job.Source.BlobstoreId)
	if err != nil {
		err = bosherr.WrapError(err, "Getting job source from blobstore")
		return
	}

	defer s.blobstore.CleanUp(file)

	tmpDir, err := fs.TempDir("bosh-agent-applier-jobapplier-RenderedJobApplier-Apply")
	if err != nil {
		err = bosherr.WrapError(err, "Getting temp dir")
		return
	}

	err = s.compressor.DecompressFileToDir(file, tmpDir)
	if err != nil {
		err = bosherr.WrapError(err, "Decompressing files to temp dir")
		return
	}

	err = fs.CopyDirEntries(filepath.Join(tmpDir, job.Source.PathInArchive), jobDir)
	if err != nil {
		err = bosherr.WrapError(err, "Copying job files to install dir")
		return
	}

	files, err := fs.Glob(filepath.Join(jobDir, "bin", "*"))
	if err != nil {
		err = bosherr.WrapError(err, "Finding job binary files")
		return
	}

	for _, f := range files {
		err = fs.Chmod(f, os.FileMode(0755))
		if err != nil {
			err = bosherr.WrapError(err, "Making %s executable", f)
			return
		}
	}

	return s.jobsBc.Enable(job)
}
