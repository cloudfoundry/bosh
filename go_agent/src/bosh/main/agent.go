package main

import (
	boshapp "bosh/app"
	"bosh/logger"
	"os"
)

func main() {
	app := boshapp.New()
	err := app.Run(os.Args)

	if err != nil {
		logger.Error("Main", err.Error())
		os.Exit(1)
	}
}
