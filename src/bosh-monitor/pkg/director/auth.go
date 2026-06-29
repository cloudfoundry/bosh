package director

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

type AuthProvider struct {
	authInfo       map[string]interface{}
	user           string
	password       string
	clientID       string
	clientSecret   string
	uaaCACert      string
	directorCACert string
	logger         *slog.Logger

	mu       sync.Mutex
	uaaToken *uaaTokenInfo
}

type uaaTokenInfo struct {
	accessToken string
	expiresAt   time.Time
}

func NewAuthProvider(authInfo map[string]interface{}, cfg Config, logger *slog.Logger) *AuthProvider {
	return &AuthProvider{
		authInfo:       authInfo,
		user:           cfg.User,
		password:       cfg.Password,
		clientID:       cfg.ClientID,
		clientSecret:   cfg.ClientSecret,
		uaaCACert:      cfg.UAACACert,
		directorCACert: cfg.DirectorCACert,
		logger:         logger,
	}
}

// uaaCACertPath returns the CA cert file path to use for UAA token requests,
// mirroring the Ruby AuthProvider#ca_file_path logic:
// prefer uaa_ca_cert when it points to a usable file, otherwise fall back to
// director_ca_cert (usability not checked — the TLS stack will handle it).
func (ap *AuthProvider) uaaCACertPath() string {
	if usableCACertFile(ap.uaaCACert) {
		return ap.uaaCACert
	}
	return ap.directorCACert
}

func (ap *AuthProvider) AuthHeader() string {
	userAuth, _ := ap.authInfo["user_authentication"].(map[string]interface{})
	authType, _ := userAuth["type"].(string)

	if authType == "uaa" {
		options, _ := userAuth["options"].(map[string]interface{})
		uaaURL, _ := options["url"].(string)
		return ap.uaaTokenHeader(uaaURL)
	}

	return "Basic " + base64.StdEncoding.EncodeToString([]byte(ap.user+":"+ap.password))
}

func (ap *AuthProvider) uaaTokenHeader(uaaURL string) string {
	ap.mu.Lock()
	defer ap.mu.Unlock()

	if ap.uaaToken != nil && time.Until(ap.uaaToken.expiresAt) > 60*time.Second {
		return "Bearer " + ap.uaaToken.accessToken
	}

	token, err := ap.fetchUAAToken(uaaURL)
	if err != nil {
		ap.logger.Error("Failed to obtain token from UAA", "error", err)
		return ""
	}
	ap.uaaToken = token
	return "Bearer " + token.accessToken
}

func (ap *AuthProvider) fetchUAAToken(uaaURL string) (*uaaTokenInfo, error) {
	data := url.Values{
		"grant_type":    {"client_credentials"},
		"client_id":     {ap.clientID},
		"client_secret": {ap.clientSecret},
	}

	tokenURL := strings.TrimRight(uaaURL, "/") + "/oauth/token"

	client := &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: tlsConfigForCAFile(ap.uaaCACertPath(), ap.logger),
		},
		Timeout: 30 * time.Second,
	}

	resp, err := client.PostForm(tokenURL, data)
	if err != nil {
		return nil, fmt.Errorf("UAA token request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read UAA response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("UAA returned status %d: %s", resp.StatusCode, string(body))
	}

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.Unmarshal(body, &tokenResp); err != nil {
		return nil, fmt.Errorf("failed to parse UAA token response: %w", err)
	}

	return &uaaTokenInfo{
		accessToken: tokenResp.AccessToken,
		expiresAt:   time.Now().Add(time.Duration(tokenResp.ExpiresIn) * time.Second),
	}, nil
}
