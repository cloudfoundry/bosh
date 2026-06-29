package director

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

// Config holds the director connection settings. Using a typed struct (rather
// than map[string]interface{}) keeps the field names checked at compile time
// and removes the fmt.Sprintf("%v", ...) coercions that the map form required.
type Config struct {
	Endpoint       string
	User           string
	Password       string
	ClientID       string
	ClientSecret   string
	DirectorCACert string
	UAACACert      string
}

type Client struct {
	endpoint string
	cfg      Config
	logger   *slog.Logger
	client   *http.Client

	authMu       sync.Mutex
	authProvider *AuthProvider
}

func NewClient(cfg Config, logger *slog.Logger) *Client {
	return &Client{
		endpoint: cfg.Endpoint,
		cfg:      cfg,
		logger:   logger,
		client: &http.Client{
			Transport: &http.Transport{
				TLSClientConfig: tlsConfigForCAFile(cfg.DirectorCACert, logger),
			},
			Timeout: 30 * time.Second,
		},
	}
}

// tlsConfigForCAFile returns a TLS configuration that verifies the peer.
// If caCertPath points to a usable file, its certificates are used as the
// trusted root CAs. Otherwise the system default trust store is used.
func tlsConfigForCAFile(caCertPath string, logger *slog.Logger) *tls.Config {
	cfg := &tls.Config{}
	if !usableCACertFile(caCertPath) {
		return cfg
	}

	pem, err := os.ReadFile(caCertPath)
	if err != nil {
		if logger != nil {
			logger.Warn("Failed to read director CA cert; falling back to system trust store",
				"path", caCertPath, "error", err)
		}
		return cfg
	}

	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM(pem) {
		if logger != nil {
			logger.Warn("Director CA cert did not contain any usable PEM blocks; falling back to system trust store",
				"path", caCertPath)
		}
		return cfg
	}

	cfg.RootCAs = pool
	return cfg
}

// usableCACertFile reports whether the given path is a non-empty CA cert file.
func usableCACertFile(path string) bool {
	if path == "" {
		return false
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	return len(strings.TrimSpace(string(data))) > 0
}

func (c *Client) Deployments() ([]Deployment, error) {
	body, status, err := c.performRequest("GET", "/deployments?exclude_configs=true&exclude_releases=true&exclude_stemcells=true")
	if err != nil {
		return nil, fmt.Errorf("unable to send get /deployments to director: %w", err)
	}
	if status != 200 {
		return nil, fmt.Errorf("cannot get deployments from director at %s/deployments?exclude_configs=true&exclude_releases=true&exclude_stemcells=true: %d %s", c.endpoint, status, body)
	}
	var deployments []Deployment
	if err := json.Unmarshal([]byte(body), &deployments); err != nil {
		return nil, fmt.Errorf("cannot parse director response: %w", err)
	}
	return deployments, nil
}

func (c *Client) ResurrectionConfig() ([]ResurrectionConfig, error) {
	body, status, err := c.performRequest("GET", "/configs?type=resurrection&latest=true")
	if err != nil {
		return nil, fmt.Errorf("unable to send get /configs to director: %w", err)
	}
	if status != 200 {
		return nil, fmt.Errorf("cannot get resurrection config from director at %s/configs?type=resurrection&latest=true: %d %s", c.endpoint, status, body)
	}
	var configs []ResurrectionConfig
	if err := json.Unmarshal([]byte(body), &configs); err != nil {
		return nil, fmt.Errorf("cannot parse director response: %w", err)
	}
	return configs, nil
}

func (c *Client) GetDeploymentInstances(name string) ([]Instance, error) {
	path := fmt.Sprintf("/deployments/%s/instances", name)
	body, status, err := c.performRequest("GET", path)
	if err != nil {
		return nil, fmt.Errorf("unable to send get %s to director: %w", path, err)
	}
	if status != 200 {
		return nil, fmt.Errorf("cannot get deployment '%s' from director at %s%s: %d %s", name, c.endpoint, path, status, body)
	}
	var instances []Instance
	if err := json.Unmarshal([]byte(body), &instances); err != nil {
		return nil, fmt.Errorf("cannot parse director response: %w", err)
	}
	return instances, nil
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
	// Guard lazy initialization: getAuthHeader is reached both from the
	// (serialized) director poll and from concurrent plugin HTTP-request
	// goroutines, which would otherwise race on authProvider (and duplicate the
	// Info() call).
	c.authMu.Lock()
	provider := c.authProvider
	if provider == nil {
		info, err := c.Info()
		if err != nil {
			c.authMu.Unlock()
			c.logger.Error("Failed to get director info for auth", "error", err)
			return ""
		}
		provider = NewAuthProvider(info, c.cfg, c.logger)
		c.authProvider = provider
	}
	c.authMu.Unlock()
	return provider.AuthHeader()
}
