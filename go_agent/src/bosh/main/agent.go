package main

import (
	"bosh/bootstrap"
	"bosh/filesystem"
	"bosh/infrastructure"
)

func main() {
	fs := filesystem.OsFileSystem{}
	infrastructure := infrastructure.NewAwsInfrastructure("http://169.254.169.254")

	b := bootstrap.New(fs, infrastructure)
	b.Run()
}
