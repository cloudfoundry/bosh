package compiler

import (
	boshblobstore "bosh/blobstore"
	boshplatform "bosh/platform"
	boshdirs "bosh/settings/directories"
)

type Provider struct {
	platform    boshplatform.Platform
	blobstore   boshblobstore.Blobstore
	dirProvider boshdirs.DirectoriesProvider
}

func NewCompilerProvider(
	platform boshplatform.Platform,
	blobstore boshblobstore.Blobstore,
	dirProvider boshdirs.DirectoriesProvider,
) (p Provider) {
	p.platform = platform
	p.blobstore = blobstore
	p.dirProvider = dirProvider
	return
}

func (p Provider) Get() (c Compiler) {
	blobstore := p.blobstore
	compressor := p.platform.GetCompressor()
	fs := p.platform.GetFs()
	runner := p.platform.GetRunner()

	return newConcreteCompiler(compressor, blobstore, fs, runner, p.dirProvider)
}
