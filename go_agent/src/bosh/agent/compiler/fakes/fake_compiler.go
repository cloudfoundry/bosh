package fakes

import (
	boshmodels "bosh/agent/applier/models"
	boshcomp "bosh/agent/compiler"
)

type FakeCompiler struct {
	CompilePkg    boshcomp.Package
	CompileDeps   []boshmodels.Package
	CompileBlobID string
	CompileSha1   string
	CompileErr    error
}

func NewFakeCompiler() (c *FakeCompiler) {
	c = new(FakeCompiler)
	return
}

func (c *FakeCompiler) Compile(pkg boshcomp.Package, deps []boshmodels.Package) (blobID, sha1 string, err error) {
	c.CompilePkg = pkg
	c.CompileDeps = deps
	blobID = c.CompileBlobID
	sha1 = c.CompileSha1
	err = c.CompileErr
	return
}
