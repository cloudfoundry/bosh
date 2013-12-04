package main

import (
	boshapp "bosh/app"
	boshlog "bosh/logger"
	"os"
)

func main() {
	logger := boshlog.NewLogger(boshlog.LEVEL_DEBUG)
	defer logger.HandlePanic("Main")

	app := boshapp.New(logger)
	err := app.Run(os.Args)

	if err != nil {
		logger.Error("Main", err.Error())
		os.Exit(1)
	}
}
