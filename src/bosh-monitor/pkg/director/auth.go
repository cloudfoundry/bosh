package director

import (
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
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
	uaaPublicKey   string
	logger         *slog.Logger

	// uaaClient is reused across all token fetches so the underlying TCP
	// connection pool and TLS sessions are shared rather than leaked.
	uaaClient *http.Client

	// mu protects uaaToken for reads and writes.
	mu sync.RWMutex
	// fetchMu serialises concurrent token-refresh calls so only one HTTP
	// request is in flight at a time. It is NOT held during the fast-path
	// cached-token read, so callers never block for 30 s on a cache hit.
	fetchMu  sync.Mutex
	uaaToken *uaaTokenInfo
}

type uaaTokenInfo struct {
	accessToken string
	expiresAt   time.Time
}

func NewAuthProvider(authInfo map[string]interface{}, cfg Config, logger *slog.Logger) *AuthProvider {
	ap := &AuthProvider{
		authInfo:       authInfo,
		user:           cfg.User,
		password:       cfg.Password,
		clientID:       cfg.ClientID,
		clientSecret:   cfg.ClientSecret,
		uaaCACert:      cfg.UAACACert,
		directorCACert: cfg.DirectorCACert,
		uaaPublicKey:   cfg.UAAPublicKey,
		logger:         logger,
	}
	// Build the UAA HTTP client once so the connection pool and TLS sessions
	// are reused across token refreshes rather than leaked on each call.
	ap.uaaClient = &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: tlsConfigForCAFile(ap.uaaCACertPath(), logger),
		},
		Timeout: 30 * time.Second,
	}
	return ap
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
	// Fast path: return the cached token without blocking other callers.
	ap.mu.RLock()
	t := ap.uaaToken
	ap.mu.RUnlock()
	if t != nil && time.Until(t.expiresAt) > 60*time.Second {
		return "Bearer " + t.accessToken
	}

	// Slow path: exactly one goroutine performs the HTTP fetch; the rest
	// wait and then read the result instead of each making their own request.
	ap.fetchMu.Lock()
	defer ap.fetchMu.Unlock()

	// Re-check after acquiring the fetch lock; a concurrent goroutine may
	// have refreshed the token while we were waiting.
	ap.mu.RLock()
	t = ap.uaaToken
	ap.mu.RUnlock()
	if t != nil && time.Until(t.expiresAt) > 60*time.Second {
		return "Bearer " + t.accessToken
	}

	token, err := ap.fetchUAAToken(uaaURL)
	if err != nil {
		ap.logger.Error("Failed to obtain token from UAA", "error", err)
		return ""
	}
	ap.mu.Lock()
	ap.uaaToken = token
	ap.mu.Unlock()
	return "Bearer " + token.accessToken
}

func (ap *AuthProvider) fetchUAAToken(uaaURL string) (*uaaTokenInfo, error) {
	data := url.Values{
		"grant_type":    {"client_credentials"},
		"client_id":     {ap.clientID},
		"client_secret": {ap.clientSecret},
	}

	tokenURL := strings.TrimRight(uaaURL, "/") + "/oauth/token"

	resp, err := ap.uaaClient.PostForm(tokenURL, data)
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

	// Mirror Ruby UAAToken decode_options: when uaa_public_key is configured,
	// verify the JWT RS256 signature. This guards against a compromised token
	// even when the TLS channel is intact.
	if pubKey := strings.TrimSpace(ap.uaaPublicKey); pubKey != "" {
		if err := verifyJWTRS256(tokenResp.AccessToken, pubKey); err != nil {
			return nil, fmt.Errorf("UAA JWT signature verification failed: %w", err)
		}
	}

	return &uaaTokenInfo{
		accessToken: tokenResp.AccessToken,
		expiresAt:   time.Now().Add(time.Duration(tokenResp.ExpiresIn) * time.Second),
	}, nil
}

// verifyJWTRS256 verifies that the JWT was signed with the RSA private key
// corresponding to pemPublicKey. It mirrors the Ruby UAAToken decode_options
// path where { pkey: @uaa_public_key, verify: true } is passed to
// CF::UAA::TokenCoder.decode when a public key is configured.
//
// Only RS256 (RSASSA-PKCS1-v1.5 with SHA-256) is accepted because that is
// the algorithm UAA uses for its signing keys.
func verifyJWTRS256(jwtToken, pemPublicKey string) error {
	parts := strings.SplitN(jwtToken, ".", 3)
	if len(parts) != 3 {
		return fmt.Errorf("invalid JWT: expected 3 parts, got %d", len(parts))
	}

	// Decode the header to confirm alg=RS256.
	headerBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return fmt.Errorf("invalid JWT header encoding: %w", err)
	}
	var header struct {
		Alg string `json:"alg"`
	}
	if err := json.Unmarshal(headerBytes, &header); err != nil {
		return fmt.Errorf("invalid JWT header JSON: %w", err)
	}
	if header.Alg != "RS256" {
		return fmt.Errorf("unsupported JWT algorithm %q: only RS256 is supported", header.Alg)
	}

	// Decode the signature.
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return fmt.Errorf("invalid JWT signature encoding: %w", err)
	}

	// Hash the signing input (header + "." + payload).
	signingInput := parts[0] + "." + parts[1]
	digest := sha256.Sum256([]byte(signingInput))

	// Parse the RSA public key from PEM.
	block, _ := pem.Decode([]byte(pemPublicKey))
	if block == nil {
		return fmt.Errorf("failed to decode PEM block from uaa_public_key")
	}
	pub, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return fmt.Errorf("failed to parse RSA public key: %w", err)
	}
	rsaPub, ok := pub.(*rsa.PublicKey)
	if !ok {
		return fmt.Errorf("uaa_public_key is not an RSA public key")
	}

	return rsa.VerifyPKCS1v15(rsaPub, crypto.SHA256, digest[:], sig)
}
