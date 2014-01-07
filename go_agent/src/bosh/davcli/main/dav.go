package main

import (
	"bosh/davcli/app"
	"bosh/davcli/cmd"
	"fmt"
	"os"
)

func main() {
	cmdFactory := cmd.NewFactory()
	cmdRunner := cmd.NewRunner(cmdFactory)

	cli := app.New(cmdRunner)
	err := cli.Run(os.Args)
	if err != nil {
		fmt.Printf("Error running app - %s", err.Error())
		os.Exit(1)
	}
}
