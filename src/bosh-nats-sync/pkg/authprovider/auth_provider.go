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

// httpClientTimeout bounds a single UAA token request.
const httpClientTimeout = 30 * time.Second

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

	mu         sync.Mutex
	token      *oauth2.Token
	cfg        *clientcredentials.Config
	httpClient *http.Client
}

func New(info InfoResponse, cfg config.DirectorConfig, logger *slog.Logger) *AuthProvider {
	return &AuthProvider{
		info:   info,
		config: cfg,
		logger: logger,
	}
}

func (a *AuthProvider) AuthHeader(ctx context.Context) (string, error) {
	if a.info.UserAuthentication != nil && a.info.UserAuthentication.Type == "uaa" {
		return a.uaaTokenHeader(ctx, a.info.UserAuthentication.Options.URL)
	}
	return "Basic " + base64.StdEncoding.EncodeToString(
		[]byte(a.config.User+":"+a.config.Password)), nil
}

func (a *AuthProvider) uaaTokenHeader(ctx context.Context, uaaURL string) (string, error) {
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
		a.httpClient = httpClient
	}

	tokenCtx := context.WithValue(ctx, oauth2.HTTPClient, a.httpClient)
	tok, err := a.cfg.Token(tokenCtx)
	if err != nil {
		return "", fmt.Errorf("failed to obtain token from UAA: %w", err)
	}
	a.token = tok
	return formatBearer(tok), nil
}

func (a *AuthProvider) buildHTTPClient() (*http.Client, error) {
	tlsCfg := &tls.Config{MinVersion: tls.VersionTLS12}

	caCertPath := a.CAFilePath()
	if caCertPath != "" {
		data, err := os.ReadFile(caCertPath)
		if err != nil {
			return nil, fmt.Errorf("failed to read CA cert file %q: %w", caCertPath, err)
		}
		if len(strings.TrimSpace(string(data))) > 0 {
			pool := x509.NewCertPool()
			if !pool.AppendCertsFromPEM(data) {
				return nil, fmt.Errorf("failed to parse CA certificate from %q", caCertPath)
			}
			tlsCfg.RootCAs = pool
		}
	}

	return &http.Client{
		Timeout:   httpClientTimeout,
		Transport: &http.Transport{TLSClientConfig: tlsCfg},
	}, nil
}

// CAFilePath mirrors the Ruby AuthProvider: prefer uaa_ca_cert when it points
// to a file that exists and has non-empty content; otherwise fall back to
// director_ca_cert.
func (a *AuthProvider) CAFilePath() string {
	if uaa := a.config.UAACACert; uaa != "" {
		if data, err := os.ReadFile(uaa); err == nil && len(strings.TrimSpace(string(data))) > 0 {
			return uaa
		}
	}
	return a.config.DirectorCACert
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
