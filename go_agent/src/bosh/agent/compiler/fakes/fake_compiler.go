package fakes

import boshcomp "bosh/agent/compiler"

type FakeCompiler struct {
	CompilePkg    boshcomp.Package
	CompileDeps   boshcomp.Dependencies
	CompileBlobId string
	CompileSha1   string
	CompileErr    error
}

func NewFakeCompiler() (c *FakeCompiler) {
	c = new(FakeCompiler)
	return
}

func (c *FakeCompiler) Compile(pkg boshcomp.Package, deps boshcomp.Dependencies) (blobId, sha1 string, err error) {
	c.CompilePkg = pkg
	c.CompileDeps = deps
	blobId = c.CompileBlobId
	sha1 = c.CompileSha1
	err = c.CompileErr
	return
}
