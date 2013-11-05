package platform

import (
	"bosh/system"
	"errors"
	"fmt"
)

type provider struct {
	platforms map[string]Platform
}

func NewProvider(fs system.FileSystem, cmdRunner system.CmdRunner) (p provider) {
	p.platforms = map[string]Platform{
		"ubuntu": newUbuntuPlatform(fs, cmdRunner),
		"dummy":  newDummyPlatform(),
	}
	return
}

func (p provider) Get(name string) (plat Platform, err error) {
	plat, found := p.platforms[name]

	if !found {
		err = errors.New(fmt.Sprintf("Platform %s could not be found", name))
	}
	return
}
