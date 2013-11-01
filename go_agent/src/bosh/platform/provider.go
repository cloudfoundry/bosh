package platform

import (
	"bosh/filesystem"
	"errors"
	"fmt"
)

type provider struct {
	platforms map[string]Platform
}

func NewProvider(fs filesystem.FileSystem) (p provider) {
	p.platforms = map[string]Platform{
		"ubuntu": newUbuntuPlatform(fs),
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
