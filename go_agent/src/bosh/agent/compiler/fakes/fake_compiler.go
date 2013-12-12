package fakes

import boshcomp "bosh/agent/compiler"

type FakeCompiler struct {
	CompilePkg    boshcomp.Package
	CompileDeps   boshcomp.Dependencies
	CompileBlobId string
	CompileErr    error
}

func NewFakeCompiler() (c *FakeCompiler) {
	c = new(FakeCompiler)
	return
}

func (c *FakeCompiler) Compile(pkg boshcomp.Package, deps boshcomp.Dependencies) (blobId string, err error) {
	c.CompilePkg = pkg
	c.CompileDeps = deps
	blobId = c.CompileBlobId
	err = c.CompileErr
	return
}
