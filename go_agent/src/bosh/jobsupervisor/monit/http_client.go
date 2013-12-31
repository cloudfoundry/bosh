package monit

import (
	bosherr "bosh/errors"
	"code.google.com/p/go-charset/charset"
	_ "code.google.com/p/go-charset/data"
	"encoding/xml"
	"io/ioutil"
	"net/http"
	"net/url"
	"path"
	"strings"
)

type httpClient struct {
	host     string
	username string
	password string
}

func NewHttpClient(host, username, password string) (client httpClient) {
	return httpClient{
		host:     host,
		username: username,
		password: password,
	}
}

func (client httpClient) ServicesInGroup(name string) (services []string, err error) {
	status, err := client.status()
	if err != nil {
		err = bosherr.WrapError(err, "Getting status from Monit")
		return
	}

	serviceGroup, found := status.ServiceGroups.Get(name)
	if !found {
		services = []string{}
	}

	services = serviceGroup.Services
	return
}

func (client httpClient) StartService(name string) (err error) {
	endpoint := client.monitUrl(name)
	request, err := http.NewRequest("POST", endpoint.String(), strings.NewReader("action=start"))
	request.SetBasicAuth(client.username, client.password)
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	httpClient := http.DefaultClient
	response, err := httpClient.Do(request)
	if err != nil {
		err = bosherr.WrapError(err, "Sending start request to monit")
		return
	}
	defer response.Body.Close()

	err = client.validateResponse(response)
	if err != nil {
		err = bosherr.WrapError(err, "Starting Monit service %s", name)
	}
	return
}

func (client httpClient) StopService(name string) (err error) {
	endpoint := client.monitUrl(name)
	request, err := http.NewRequest("POST", endpoint.String(), strings.NewReader("action=stop"))
	request.SetBasicAuth(client.username, client.password)
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	httpClient := http.DefaultClient
	response, err := httpClient.Do(request)
	if err != nil {
		err = bosherr.WrapError(err, "Sending stop request to monit")
		return
	}
	defer response.Body.Close()

	err = client.validateResponse(response)
	if err != nil {
		err = bosherr.WrapError(err, "Stopping Monit service %s", name)
	}
	return
}

func (client httpClient) Status() (status Status, err error) {
	return client.status()
}

func (client httpClient) status() (status status, err error) {
	endpoint := client.monitUrl("/_status2")
	endpoint.RawQuery = "format=xml"
	request, err := http.NewRequest("GET", endpoint.String(), nil)
	request.SetBasicAuth(client.username, client.password)

	httpClient := http.DefaultClient
	response, err := httpClient.Do(request)
	if err != nil {
		err = bosherr.WrapError(err, "Sending status request to monit")
		return
	}
	defer response.Body.Close()

	err = client.validateResponse(response)
	if err != nil {
		err = bosherr.WrapError(err, "Getting monit status")
		return
	}

	decoder := xml.NewDecoder(response.Body)
	decoder.CharsetReader = charset.NewReader

	err = decoder.Decode(&status)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling Monit status")
	}
	return
}

func (client httpClient) monitUrl(thing string) (endpoint url.URL) {
	endpoint = url.URL{
		Scheme: "http",
		Host:   client.host,
		Path:   path.Join("/", thing),
	}
	return
}

func (client httpClient) validateResponse(response *http.Response) (err error) {
	if response.StatusCode == http.StatusOK {
		return
	}

	body, err := ioutil.ReadAll(response.Body)
	if err != nil {
		err = bosherr.WrapError(err, "Reading body of failed Monit response")
		return
	}
	err = bosherr.New("Request failed with %s: %s", response.Status, string(body))
	return
}
