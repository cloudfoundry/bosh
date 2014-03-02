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

func TestGetRunWithValidArgs(t *testing.T) {
	requestedBlob := "0ca907f2-dde8-4413-a304-9076c9d0978b"
	targetFilePath := filepath.Join(os.TempDir(), "testRunGetCommand.txt")
	defer os.RemoveAll(targetFilePath)

	handler := func(w http.ResponseWriter, r *http.Request) {
		req := testcmd.NewHttpRequest(r)

		username, password, err := req.ExtractBasicAuth()

		assert.NoError(t, err)
		assert.Equal(t, req.URL.Path, "/0d/"+requestedBlob)
		assert.Equal(t, req.Method, "GET")
		assert.Equal(t, username, "some user")
		assert.Equal(t, password, "some pwd")

		w.Write([]byte("this is your blob"))
	}

	ts := httptest.NewServer(http.HandlerFunc(handler))
	defer ts.Close()

	config := davconf.Config{
		User:     "some user",
		Password: "some pwd",
		Endpoint: ts.URL,
	}

	err := runGet(config, []string{requestedBlob, targetFilePath})
	assert.NoError(t, err)
	assert.Equal(t, getFileContent(targetFilePath), "this is your blob")
}

func TestGetRunWithIncorrectArgCount(t *testing.T) {
	config := davconf.Config{}
	err := runGet(config, []string{})

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Incorrect usage")
}

func runGet(config davconf.Config, args []string) (err error) {
	factory := NewFactory()
	factory.SetConfig(config)
	cmd, _ := factory.Create("get")
	return cmd.Run(args)
}

func getFileContent(path string) (content string) {
	file, _ := os.Open(path)
	fileBytes, _ := ioutil.ReadAll(file)
	content = string(fileBytes)
	return
}
