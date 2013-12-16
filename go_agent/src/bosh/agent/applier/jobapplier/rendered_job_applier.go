package jobapplier

import (
	bc "bosh/agent/applier/bundlecollection"
	models "bosh/agent/applier/models"
	boshblob "bosh/blobstore"
	boshdisk "bosh/platform/disk"
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

func (s *renderedJobApplier) Apply(job models.Job) error {
	fs, jobDir, err := s.jobsBc.Install(job)
	if err != nil {
		return err
	}

	file, err := s.blobstore.Get(job.Source.BlobstoreId)
	if err != nil {
		return err
	}

	defer s.blobstore.CleanUp(file)

	tmpDir, err := fs.TempDir("bosh-agent-applier-jobapplier-RenderedJobApplier-Apply")
	if err != nil {
		return err
	}

	err = s.compressor.DecompressFileToDir(file, tmpDir)
	if err != nil {
		return err
	}

	err = fs.CopyDirEntries(tmpDir, jobDir)
	if err != nil {
		return err
	}

	return s.jobsBc.Enable(job)
}
