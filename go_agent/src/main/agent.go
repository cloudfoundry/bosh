package main

import (
	"agent"
)

func main() {
	fs := agent.OsFileSystem{}
	infrastructure := agent.NewAwsInfrastructure("http://169.254.169.254")

	agent.Run(fs, infrastructure)
}
