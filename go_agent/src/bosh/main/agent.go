package main

import (
	"bosh/bootstrap"
	"bosh/filesystem"
	"bosh/infrastructure"
	"fmt"
	"os"
)

func main() {
	fs := filesystem.OsFileSystem{}
	infrastructure := infrastructure.NewAwsInfrastructure("http://169.254.169.254")

	b := bootstrap.New(fs, infrastructure)
	err := b.Run()
	if err != nil {
		failWithError(err)
		return
	}
}

func failWithError(err error) {
	fmt.Fprintf(os.Stderr, err.Error())
	os.Exit(1)
}
