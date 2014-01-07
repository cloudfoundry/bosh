package cmd

import (
	davclient "bosh/davcli/client"
	testcmd "bosh/davcli/cmd/testing"
	davconf "bosh/davcli/config"
	"github.com/stretchr/testify/assert"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestPutRunWithValidArgs(t *testing.T) {
	pwd, _ := os.Getwd()
	sourceFilePath := filepath.Join(pwd, "../../../../fixtures/cat.jpg")
	targetBlob := "/path/to/cat.jpg"
	serverWasHit := false

	handler := func(w http.ResponseWriter, r *http.Request) {
		serverWasHit = true
		req := testcmd.NewHttpRequest(r)

		username, password, err := req.ExtractBasicAuth()

		assert.NoError(t, err)
		assert.Equal(t, req.URL.Path, targetBlob)
		assert.Equal(t, req.Method, "PUT")
		assert.Equal(t, username, "some user")
		assert.Equal(t, password, "some pwd")

		expectedBytes := fileBytes(sourceFilePath)
		actualBytes, _ := ioutil.ReadAll(r.Body)
		assert.Equal(t, expectedBytes, actualBytes)

		w.WriteHeader(200)
	}

	ts := httptest.NewServer(http.HandlerFunc(handler))
	defer ts.Close()

	config := davconf.Config{
		Username: "some user",
		Password: "some pwd",
		Endpoint: ts.URL,
	}

	err := runPut(config, []string{sourceFilePath, targetBlob})
	assert.NoError(t, err)
	assert.True(t, serverWasHit)
}

func TestPutRunWithIncorrectArgCount(t *testing.T) {
	config := davconf.Config{}
	err := runPut(config, []string{})

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Incorrect usage")
}

func runPut(config davconf.Config, args []string) (err error) {
	davClient := davclient.NewClient(config)
	cmd := newPutCmd(davClient)
	return cmd.Run(args)
}

func fileBytes(path string) (content []byte) {
	f, _ := os.Open(path)
	content, _ = ioutil.ReadAll(f)
	return
}
