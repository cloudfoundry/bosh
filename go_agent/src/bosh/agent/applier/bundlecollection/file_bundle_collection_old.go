package bundlecollection

import (
	boshsys "bosh/system"
)

type FileBundleCollectionOld struct {
	inner FileBundleCollection
}

func NewFileBundleCollectionOld(inner FileBundleCollection) (collection FileBundleCollectionOld) {
	collection.inner = inner
	return
}

func (self FileBundleCollectionOld) Install(definition BundleDefinition) (fs boshsys.FileSystem, path string, err error) {
	bundle, err := self.inner.Get(definition)
	if err != nil {
		return
	}

	fs, path, err = bundle.Install()
	return
}

func (self FileBundleCollectionOld) GetDir(definition BundleDefinition) (fs boshsys.FileSystem, path string, err error) {
	bundle, err := self.inner.Get(definition)
	if err != nil {
		return
	}

	fs, path, err = bundle.GetInstallPath()
	return
}

func (self FileBundleCollectionOld) Enable(definition BundleDefinition) (err error) {
	bundle, err := self.inner.Get(definition)
	if err != nil {
		return
	}

	err = bundle.Enable()
	return
}
