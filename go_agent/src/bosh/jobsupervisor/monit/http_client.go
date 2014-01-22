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
	"time"
)

type httpClient struct {
	host                string
	username            string
	password            string
	retryAttempts       int
	delayBetweenRetries time.Duration
	client              HttpClient
}

func NewHttpClient(host, username, password string, client HttpClient) httpClient {
	return httpClient{
		host:                host,
		username:            username,
		password:            password,
		client:              client,
		retryAttempts:       20,
		delayBetweenRetries: 1 * time.Second,
	}
}

func (c httpClient) ServicesInGroup(name string) (services []string, err error) {
	status, err := c.status()
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

func (c httpClient) StartService(serviceName string) (err error) {
	response, err := c.makeRequest(serviceName, "POST")

	if err != nil {
		err = bosherr.WrapError(err, "Sending start request to monit")
		return
	}
	defer response.Body.Close()

	err = c.validateResponse(response)
	if err != nil {
		err = bosherr.WrapError(err, "Starting Monit service %s", serviceName)
	}
	return
}

func (c httpClient) StopService(name string) (err error) {
	endpoint := c.monitUrl(name)
	request, err := http.NewRequest("POST", endpoint.String(), strings.NewReader("action=stop"))
	request.SetBasicAuth(c.username, c.password)
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	httpClient := http.DefaultClient
	response, err := httpClient.Do(request)
	if err != nil {
		err = bosherr.WrapError(err, "Sending stop request to monit")
		return
	}
	defer response.Body.Close()

	err = c.validateResponse(response)
	if err != nil {
		err = bosherr.WrapError(err, "Stopping Monit service %s", name)
	}
	return
}

func (c httpClient) Status() (status Status, err error) {
	return c.status()
}

func (c httpClient) status() (status status, err error) {
	endpoint := c.monitUrl("/_status2")
	endpoint.RawQuery = "format=xml"
	request, err := http.NewRequest("GET", endpoint.String(), nil)
	request.SetBasicAuth(c.username, c.password)

	httpClient := http.DefaultClient
	response, err := httpClient.Do(request)
	if err != nil {
		err = bosherr.WrapError(err, "Sending status request to monit")
		return
	}
	defer response.Body.Close()

	err = c.validateResponse(response)
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

func (c httpClient) monitUrl(thing string) (endpoint url.URL) {
	endpoint = url.URL{
		Scheme: "http",
		Host:   c.host,
		Path:   path.Join("/", thing),
	}
	return
}

func (c httpClient) validateResponse(response *http.Response) (err error) {
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

func (c httpClient) makeRequest(serviceName, method string) (response *http.Response, err error) {
	endpoint := c.monitUrl(serviceName)
	request, err := http.NewRequest(method, endpoint.String(), strings.NewReader("action=start"))
	request.SetBasicAuth(c.username, c.password)
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	response, err = c.client.Do(request)

	attempts := 1
	for (err != nil || response.StatusCode != 200) && attempts < c.retryAttempts {
		if response != nil {
			response.Body.Close()
		}
		time.Sleep(c.delayBetweenRetries)
		response, err = c.client.Do(request)
		attempts++
	}

	return
}
