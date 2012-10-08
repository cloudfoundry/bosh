package agent

import (
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"mime/multipart"
	"net/http"
	"os"
)

type BlobstoreClient interface {
	Create(r io.Reader) (blobId string, err error)
	Get(blobId string) (blob io.ReadCloser, err error)
	Delete(blobId string) (err error)
}

type simpleBlobstoreClient struct {
	endpoint string
	bucket   string
	user     string
	password string
}

func NewBlobstoreClient(provider string, options map[string]interface{}) (BlobstoreClient, error) {
	var client BlobstoreClient

	switch provider {
	case "simple":
		return NewSimpleBlobstoreClient(options)
	default:
		return nil, fmt.Errorf("unknown blobstore provider: %s", provider)
	}

	return client, nil
}

func NewSimpleBlobstoreClient(options map[string]interface{}) (BlobstoreClient, error) {
	var ok bool

	client := &simpleBlobstoreClient{}

	if client.endpoint, ok = options["endpoint"].(string); !ok {
		return nil, errors.New("invalid blobstore endpoint, string expected")
	}
	if len(client.endpoint) == 0 {
		return nil, errors.New("blobstore endpoint is missing")
	}
	if client.user, ok = options["user"].(string); !ok {
		return nil, errors.New("invalid blobstore user, string expected")
	}
	if client.password, ok = options["password"].(string); !ok {
		return nil, errors.New("invalid blobstore password, string expected")
	}

	if _, hasBucket := options["bucket"]; hasBucket {
		if client.bucket, ok = options["bucket"].(string); !ok {
			return nil, errors.New("invalid blobstore bucket, string expected")
		}
	} else {
		client.bucket = "resources"
	}

	return client, nil
}

func (bc *simpleBlobstoreClient) Create(r io.Reader) (blobId string, err error) {
	// First we need to create a well-formed multipart body for blobstore server to handle
	tmpFile, err := ioutil.TempFile("", "blobstore-upload")
	if err != nil {
		return "", err
	}
	defer os.Remove(tmpFile.Name())

	req, err := bc.generateCreateRequest(r, tmpFile)
	if err != nil {
		return "", err
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("couldn't create an object in blobstore, got HTTP %d", resp.StatusCode)
	}

	body, err := ioutil.ReadAll(resp.Body)

	return string(body), err
}

// Get the object from blobstore.
// NOTE: client is responsible for closing response!
func (bc *simpleBlobstoreClient) Get(objectId string) (blob io.ReadCloser, err error) {
	req, err := http.NewRequest("GET", bc.objectUrl(objectId), nil)
	if err != nil {
		return nil, err
	}
	req.SetBasicAuth(bc.user, bc.password)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("could'n read an object from blobstore, got HTTP %d", resp.StatusCode)
	}

	return resp.Body, nil
}

func (bc *simpleBlobstoreClient) Delete(objectId string) (err error) {
	req, err := http.NewRequest("DELETE", bc.objectUrl(objectId), nil)
	if err != nil {
		return err
	}
	req.SetBasicAuth(bc.user, bc.password)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("couldn't delete an object from blobstore, got HTTP %d", resp.StatusCode)
	}

	return nil
}

func (bc *simpleBlobstoreClient) objectsUrl() string {
	return bc.endpoint + "/" + bc.bucket
}

func (bc *simpleBlobstoreClient) objectUrl(objectId string) string {
	return bc.objectsUrl() + "/" + objectId
}

func (bc *simpleBlobstoreClient) generateCreateRequest(in io.Reader, tmpFile *os.File) (*http.Request, error) {
	multipartBody := multipart.NewWriter(tmpFile)

	payload, err := multipartBody.CreateFormFile("content", "tempfile")
	if err != nil {
		return nil, err
	}

	if _, err := io.Copy(payload, in); err != nil { // io.Copy argument order is (dst, src)
		return nil, err
	}

	if err = multipartBody.Close(); err != nil {
		return nil, err
	}
	tmpFile.Close()

	stat, err := os.Stat(tmpFile.Name())
	if err != nil {
		return nil, err
	}
	payloadSize := stat.Size()

	payloadReader, err := os.Open(tmpFile.Name())
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", bc.objectsUrl(), payloadReader)
	if err != nil {
		return nil, err
	}

	req.ContentLength = payloadSize
	req.Header.Add("Content-Type", fmt.Sprintf("multipart/form-data; boundary=%s", multipartBody.Boundary()))
	req.SetBasicAuth(bc.user, bc.password)

	return req, nil
}
