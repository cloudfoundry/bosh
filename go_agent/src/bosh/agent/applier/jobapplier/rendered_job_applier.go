package jobapplier

import (
	bc "bosh/agent/applier/bundlecollection"
	models "bosh/agent/applier/models"
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshjobsuper "bosh/jobsupervisor"
	boshcmd "bosh/platform/commands"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type renderedJobApplier struct {
	jobsBc        bc.BundleCollection
	blobstore     boshblob.Blobstore
	compressor    boshcmd.Compressor
	jobSupervisor boshjobsuper.JobSupervisor
}

func NewRenderedJobApplier(
	jobsBc bc.BundleCollection,
	blobstore boshblob.Blobstore,
	compressor boshcmd.Compressor,
	jobSupervisor boshjobsuper.JobSupervisor,
) *renderedJobApplier {
	return &renderedJobApplier{
		jobsBc:        jobsBc,
		blobstore:     blobstore,
		compressor:    compressor,
		jobSupervisor: jobSupervisor,
	}
}

func (s *renderedJobApplier) Apply(job models.Job) (err error) {
	fs, jobDir, err := s.jobsBc.Install(job)
	if err != nil {
		err = bosherr.WrapError(err, "Installing jobs bundle collection")
		return
	}

	file, err := s.blobstore.Get(job.Source.BlobstoreId, job.Source.Sha1)
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
	defer fs.RemoveAll(tmpDir)

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

	err = s.jobsBc.Enable(job)
	if err != nil {
		err = bosherr.WrapError(err, "Enabling job")
	}
	return
}

func (s *renderedJobApplier) Configure(job models.Job, jobIndex int) (err error) {
	fs, jobDir, err := s.jobsBc.GetDir(job)
	if err != nil {
		err = bosherr.WrapError(err, "Looking up job directory")
		return
	}

	monitFilePath := filepath.Join(jobDir, "monit")
	if fs.FileExists(monitFilePath) {
		err = s.jobSupervisor.AddJob(job.Name, jobIndex, monitFilePath)
		if err != nil {
			err = bosherr.WrapError(err, "Adding monit configuration")
			return
		}
	}

	monitFilePaths, err := fs.Glob(filepath.Join(jobDir, "*.monit"))
	if err != nil {
		err = bosherr.WrapError(err, "Looking for additional monit files")
		return
	}

	for _, monitFilePath := range monitFilePaths {
		label := strings.Replace(filepath.Base(monitFilePath), ".monit", "", 1)
		subJobName := fmt.Sprintf("%s_%s", job.Name, label)

		err = s.jobSupervisor.AddJob(subJobName, jobIndex, monitFilePath)
		if err != nil {
			err = bosherr.WrapError(err, "Adding additional monit configuration %s", label)
			return
		}
	}

	return nil
}
