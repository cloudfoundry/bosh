package compiler

import (
	boshblobstore "bosh/blobstore"
	boshplatform "bosh/platform"
)

type Provider struct {
	platform  boshplatform.Platform
	blobstore boshblobstore.Blobstore
}

func NewCompilerProvider(platform boshplatform.Platform, blobstore boshblobstore.Blobstore) (p Provider) {
	p.platform = platform
	p.blobstore = blobstore
	return
}

func (p Provider) Get() (c Compiler) {
	blobstore := p.blobstore
	compressor := p.platform.GetCompressor()
	fs := p.platform.GetFs()
	runner := p.platform.GetRunner()

	return newConcreteCompiler(compressor, blobstore, fs, runner)
}
