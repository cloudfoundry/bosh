package authprovider

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"bosh-nats-sync/pkg/config"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/clientcredentials"
)

const ExpirationDeadline = 60 * time.Second

type InfoResponse struct {
	UserAuthentication *UserAuthentication `json:"user_authentication"`
}

type UserAuthentication struct {
	Type    string     `json:"type"`
	Options UAAOptions `json:"options"`
}

type UAAOptions struct {
	URL string `json:"url"`
}

type AuthProvider struct {
	info   InfoResponse
	config config.DirectorConfig
	logger *slog.Logger

	mu    sync.Mutex
	token *oauth2.Token
	cfg   *clientcredentials.Config
	ctx   context.Context
}

func New(info InfoResponse, cfg config.DirectorConfig, logger *slog.Logger) *AuthProvider {
	return &AuthProvider{
		info:   info,
		config: cfg,
		logger: logger,
	}
}

func (a *AuthProvider) AuthHeader() (string, error) {
	if a.info.UserAuthentication != nil && a.info.UserAuthentication.Type == "uaa" {
		return a.uaaTokenHeader(a.info.UserAuthentication.Options.URL)
	}
	return "Basic " + base64.StdEncoding.EncodeToString(
		[]byte(a.config.User+":"+a.config.Password)), nil
}

func (a *AuthProvider) uaaTokenHeader(uaaURL string) (string, error) {
	a.mu.Lock()
	defer a.mu.Unlock()

	if a.token != nil && time.Until(a.token.Expiry) > ExpirationDeadline {
		return formatBearer(a.token), nil
	}

	if a.cfg == nil {
		httpClient, err := a.buildHTTPClient()
		if err != nil {
			return "", fmt.Errorf("failed to build HTTP client for UAA: %w", err)
		}

		a.cfg = &clientcredentials.Config{
			ClientID:     a.config.ClientID,
			ClientSecret: a.config.ClientSecret,
			TokenURL:     strings.TrimSuffix(uaaURL, "/") + "/oauth/token",
		}
		a.ctx = context.WithValue(context.Background(), oauth2.HTTPClient, httpClient)
	}

	tok, err := a.cfg.Token(a.ctx)
	if err != nil {
		a.logger.Error("Failed to obtain token from UAA", "error", err)
		return "", nil
	}
	a.token = tok
	return formatBearer(tok), nil
}

func (a *AuthProvider) buildHTTPClient() (*http.Client, error) {
	tlsCfg := &tls.Config{}

	caCertPath := a.config.CACert
	if caCertPath != "" {
		data, err := os.ReadFile(caCertPath)
		if err == nil && len(strings.TrimSpace(string(data))) > 0 {
			pool := x509.NewCertPool()
			pool.AppendCertsFromPEM(data)
			tlsCfg.RootCAs = pool
		}
	}

	return &http.Client{
		Transport: &http.Transport{TLSClientConfig: tlsCfg},
	}, nil
}

func formatBearer(tok *oauth2.Token) string {
	return "Bearer " + tok.AccessToken
}

func ParseInfoResponse(body []byte) (InfoResponse, error) {
	var info InfoResponse
	if err := json.Unmarshal(body, &info); err != nil {
		return InfoResponse{}, err
	}
	return info, nil
}
