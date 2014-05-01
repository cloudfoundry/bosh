package monit

import (
	"encoding/xml"
	"io/ioutil"
	"net/http"
	"net/url"
	"path"
	"strings"
	"time"

	"code.google.com/p/go-charset/charset"
	_ "code.google.com/p/go-charset/data" // translations between char sets

	bosherr "bosh/errors"
	boshlog "bosh/logger"
)

type httpClient struct {
	host                string
	username            string
	password            string
	retryAttempts       int
	delayBetweenRetries time.Duration
	client              HTTPClient
	logger              boshlog.Logger
}

func NewHTTPClient(
	host, username, password string,
	client HTTPClient,
	delayBetweenRetries time.Duration,
	logger boshlog.Logger,
) httpClient {
	return httpClient{
		host:                host,
		username:            username,
		password:            password,
		client:              client,
		retryAttempts:       20,
		delayBetweenRetries: delayBetweenRetries,
		logger:              logger,
	}
}

func (c httpClient) ServicesInGroup(name string) (services []string, err error) {
	status, err := c.status()
	if err != nil {
		return nil, bosherr.WrapError(err, "Getting status from Monit")
	}

	serviceGroup, found := status.ServiceGroups.Get(name)
	if !found {
		return []string{}, nil
	}

	return serviceGroup.Services, nil
}

func (c httpClient) StartService(serviceName string) (err error) {
	response, err := c.makeRequest(c.monitURL(serviceName), "POST", "action=start")
	if err != nil {
		return bosherr.WrapError(err, "Sending start request to monit")
	}

	defer response.Body.Close()

	err = c.validateResponse(response)
	if err != nil {
		return bosherr.WrapError(err, "Starting Monit service %s", serviceName)
	}

	return nil
}

func (c httpClient) StopService(serviceName string) error {
	response, err := c.makeRequest(c.monitURL(serviceName), "POST", "action=stop")
	if err != nil {
		return bosherr.WrapError(err, "Sending stop request to monit")
	}

	defer response.Body.Close()

	err = c.validateResponse(response)
	if err != nil {
		return bosherr.WrapError(err, "Stopping Monit service %s", serviceName)
	}

	return nil
}

func (c httpClient) UnmonitorService(serviceName string) error {
	response, err := c.makeRequest(c.monitURL(serviceName), "POST", "action=unmonitor")
	if err != nil {
		return bosherr.WrapError(err, "Sending unmonitor request to monit")
	}

	defer response.Body.Close()

	err = c.validateResponse(response)
	if err != nil {
		return bosherr.WrapError(err, "Unmonitoring Monit service %s", serviceName)
	}

	return nil
}

func (c httpClient) Status() (Status, error) {
	return c.status()
}

func (c httpClient) status() (status, error) {
	url := c.monitURL("/_status2")
	url.RawQuery = "format=xml"

	response, err := c.makeRequest(url, "GET", "")
	if err != nil {
		return status{}, bosherr.WrapError(err, "Sending status request to monit")
	}

	defer response.Body.Close()

	err = c.validateResponse(response)
	if err != nil {
		return status{}, bosherr.WrapError(err, "Getting monit status")
	}

	decoder := xml.NewDecoder(response.Body)
	decoder.CharsetReader = charset.NewReader

	var st status

	err = decoder.Decode(&st)
	if err != nil {
		return status{}, bosherr.WrapError(err, "Unmarshalling Monit status")
	}

	return st, nil
}

func (c httpClient) monitURL(thing string) url.URL {
	return url.URL{
		Scheme: "http",
		Host:   c.host,
		Path:   path.Join("/", thing),
	}
}

func (c httpClient) validateResponse(response *http.Response) error {
	if response.StatusCode == http.StatusOK {
		return nil
	}

	body, err := ioutil.ReadAll(response.Body)
	if err != nil {
		return bosherr.WrapError(err, "Reading body of failed Monit response")
	}

	return bosherr.New("Request failed with %s: %s", response.Status, string(body))
}

func (c httpClient) makeRequest(url url.URL, method, requestBody string) (response *http.Response, err error) {
	c.logger.Debug("http-client", "makeRequest with url %s", url.String())

	for attempt := 0; attempt < c.retryAttempts; attempt++ {
		c.logger.Debug("http-client", "Retrying %d", attempt)

		if response != nil {
			response.Body.Close()
		}

		var request *http.Request

		request, err = http.NewRequest(method, url.String(), strings.NewReader(requestBody))
		if err != nil {
			return
		}

		request.SetBasicAuth(c.username, c.password)

		request.Header.Set("Content-Type", "application/x-www-form-urlencoded")

		response, err = c.client.Do(request)
		if response != nil {
			c.logger.Debug("http-client", "Got response with status %d", response.StatusCode)
		}

		if err != nil {
			c.logger.Debug("http-client", "Got err %v", err)
		} else if response.StatusCode == 200 {
			return
		}

		time.Sleep(c.delayBetweenRetries)
	}

	return
}
