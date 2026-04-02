package director

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"
)

type Client struct {
	endpoint string
	options  map[string]interface{}
	logger   *slog.Logger
	client   *http.Client

	authProvider *AuthProvider
}

func NewClient(options map[string]interface{}, logger *slog.Logger) *Client {
	endpoint, _ := options["endpoint"].(string)
	return &Client{
		endpoint: endpoint,
		options:  options,
		logger:   logger,
		client: &http.Client{
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
			},
			Timeout: 30 * time.Second,
		},
	}
}

func (c *Client) Deployments() ([]map[string]interface{}, error) {
	body, status, err := c.performRequest("GET", "/deployments?exclude_configs=true&exclude_releases=true&exclude_stemcells=true")
	if err != nil {
		return nil, fmt.Errorf("unable to send get /deployments to director: %w", err)
	}
	if status != 200 {
		return nil, fmt.Errorf("cannot get deployments from director at %s/deployments?exclude_configs=true&exclude_releases=true&exclude_stemcells=true: %d %s", c.endpoint, status, body)
	}
	return parseJSONArray(body)
}

func (c *Client) ResurrectionConfig() ([]map[string]interface{}, error) {
	body, status, err := c.performRequest("GET", "/configs?type=resurrection&latest=true")
	if err != nil {
		return nil, fmt.Errorf("unable to send get /configs to director: %w", err)
	}
	if status != 200 {
		return nil, fmt.Errorf("cannot get resurrection config from director at %s/configs?type=resurrection&latest=true: %d %s", c.endpoint, status, body)
	}
	return parseJSONArray(body)
}

func (c *Client) GetDeploymentInstances(name string) ([]map[string]interface{}, error) {
	path := fmt.Sprintf("/deployments/%s/instances", name)
	body, status, err := c.performRequest("GET", path)
	if err != nil {
		return nil, fmt.Errorf("unable to send get %s to director: %w", path, err)
	}
	if status != 200 {
		return nil, fmt.Errorf("cannot get deployment '%s' from director at %s%s: %d %s", name, c.endpoint, path, status, body)
	}
	return parseJSONArray(body)
}

func (c *Client) Info() (map[string]interface{}, error) {
	body, status, err := c.performRequestNoAuth("GET", "/info")
	if err != nil {
		return nil, fmt.Errorf("unable to send get /info to director: %w", err)
	}
	if status != 200 {
		return nil, fmt.Errorf("cannot get status from director: %d %s", status, body)
	}
	var result map[string]interface{}
	if err := json.Unmarshal([]byte(body), &result); err != nil {
		return nil, fmt.Errorf("cannot parse director response: %w", err)
	}
	return result, nil
}

// PerformRequestForPlugin executes an HTTP request on behalf of a plugin.
func (c *Client) PerformRequestForPlugin(method, path string, headers map[string]string, body string, useDirectorAuth bool) (string, int, error) {
	fullURL := c.endpoint + path

	var bodyReader io.Reader
	if body != "" {
		bodyReader = strings.NewReader(body)
	}

	req, err := http.NewRequest(method, fullURL, bodyReader)
	if err != nil {
		return "", 0, fmt.Errorf("invalid request: %w", err)
	}

	if useDirectorAuth {
		authHeader := c.getAuthHeader()
		if authHeader != "" {
			req.Header.Set("Authorization", authHeader)
		}
	}

	for k, v := range headers {
		req.Header.Set(k, v)
	}

	resp, err := c.client.Do(req)
	if err != nil {
		return "", 0, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", resp.StatusCode, fmt.Errorf("failed to read response: %w", err)
	}

	return string(respBody), resp.StatusCode, nil
}

func (c *Client) performRequest(method, path string) (string, int, error) {
	fullURL := c.endpoint + path

	req, err := http.NewRequest(method, fullURL, nil)
	if err != nil {
		return "", 0, fmt.Errorf("invalid URI: %s", fullURL)
	}

	authHeader := c.getAuthHeader()
	if authHeader != "" {
		req.Header.Set("Authorization", authHeader)
	}

	resp, err := c.client.Do(req)
	if err != nil {
		return "", 0, fmt.Errorf("unable to send %s %s to director: %w", method, path, err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", resp.StatusCode, fmt.Errorf("failed to read response: %w", err)
	}

	return string(body), resp.StatusCode, nil
}

func (c *Client) performRequestNoAuth(method, path string) (string, int, error) {
	fullURL := c.endpoint + path

	req, err := http.NewRequest(method, fullURL, nil)
	if err != nil {
		return "", 0, fmt.Errorf("invalid URI: %s", fullURL)
	}

	resp, err := c.client.Do(req)
	if err != nil {
		return "", 0, fmt.Errorf("unable to send %s %s to director: %w", method, path, err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", resp.StatusCode, fmt.Errorf("failed to read response: %w", err)
	}

	return string(body), resp.StatusCode, nil
}

func (c *Client) getAuthHeader() string {
	if c.authProvider == nil {
		info, err := c.Info()
		if err != nil {
			c.logger.Error("Failed to get director info for auth", "error", err)
			return ""
		}
		c.authProvider = NewAuthProvider(info, c.options, c.logger)
	}
	return c.authProvider.AuthHeader()
}

func parseJSONArray(data string) ([]map[string]interface{}, error) {
	var result []map[string]interface{}
	if err := json.Unmarshal([]byte(data), &result); err != nil {
		return nil, fmt.Errorf("cannot parse director response: %w", err)
	}
	return result, nil
}
