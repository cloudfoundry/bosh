package main

import (
	"bosh/app"
	"fmt"
	"os"
)

func main() {
	a := app.New()
	err := a.Run(os.Args)

	if err != nil {
		fmt.Fprintf(os.Stderr, err.Error()+"\n")
		os.Exit(1)
	}
}
