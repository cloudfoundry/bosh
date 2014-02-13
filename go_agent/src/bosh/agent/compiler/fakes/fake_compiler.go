package fakes

import (
	boshmodels "bosh/agent/applier/models"
	boshcomp "bosh/agent/compiler"
)

type FakeCompiler struct {
	CompilePkg    boshcomp.Package
	CompileDeps   []boshmodels.Package
	CompileBlobId string
	CompileSha1   string
	CompileErr    error
}

func NewFakeCompiler() (c *FakeCompiler) {
	c = new(FakeCompiler)
	return
}

func (c *FakeCompiler) Compile(pkg boshcomp.Package, deps []boshmodels.Package) (blobId, sha1 string, err error) {
	c.CompilePkg = pkg
	c.CompileDeps = deps
	blobId = c.CompileBlobId
	sha1 = c.CompileSha1
	err = c.CompileErr
	return
}
