package cmd_test

import (
	. "bosh/davcli/cmd"
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
	targetBlob := "some-other-awesome-guid"
	serverWasHit := false

	handler := func(w http.ResponseWriter, r *http.Request) {
		serverWasHit = true
		req := testcmd.NewHttpRequest(r)

		username, password, err := req.ExtractBasicAuth()

		assert.NoError(t, err)
		assert.Equal(t, req.URL.Path, "/d1/"+targetBlob)
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
		User:     "some user",
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
	factory := NewFactory()
	factory.SetConfig(config)
	cmd, _ := factory.Create("put")
	return cmd.Run(args)
}

func fileBytes(path string) (content []byte) {
	f, _ := os.Open(path)
	content, _ = ioutil.ReadAll(f)
	return
}
