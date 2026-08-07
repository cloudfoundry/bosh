package authprovider

import (
	"context"
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"bosh-nats-sync/pkg/config"

	"code.cloudfoundry.org/tlsconfig"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/clientcredentials"
)

const ExpirationDeadline = 60 * time.Second

// httpClientTimeout bounds a single UAA token request.
// Intentionally matches userssync.httpClientTimeout (director API request).
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

	// Mirror Ruby UAAToken decode_options: when uaa_public_key is configured,
	// verify the JWT RS256 signature. This guards against a compromised token
	// even when the TLS channel is intact.
	if pubKey := strings.TrimSpace(a.config.UAAPublicKey); pubKey != "" {
		if err := verifyJWTRS256(tok.AccessToken, pubKey); err != nil {
			return "", fmt.Errorf("UAA JWT signature verification failed: %w", err)
		}
	}

	a.token = tok
	return formatBearer(tok), nil
}

// buildHTTPClient uses code.cloudfoundry.org/tlsconfig to build the TLS
// configuration for UAA token requests. WithExternalServiceDefaults() pins
// MinVersion/MaxVersion (TLS 1.2-1.3) and a curated cipher-suite list, matching
// CF's standard for talking to services we don't control on the other end.
// director_ca_cert / uaa_ca_cert (via CAFilePath) is used as the trust root
// when the file exists and has non-empty content; otherwise the system trust
// store is used, matching the Ruby AuthProvider behaviour.
func (a *AuthProvider) buildHTTPClient() (*http.Client, error) {
	caCertPath := a.CAFilePath()

	var clientOpts []tlsconfig.ClientOption
	if caCertPath != "" {
		data, err := os.ReadFile(caCertPath)
		if err != nil {
			return nil, fmt.Errorf("failed to read CA cert file %q: %w", caCertPath, err)
		}
		if len(strings.TrimSpace(string(data))) > 0 {
			clientOpts = append(clientOpts, tlsconfig.WithAuthorityFromFile(caCertPath))
		}
	}

	tlsCfg, err := tlsconfig.Build(tlsconfig.WithExternalServiceDefaults()).Client(clientOpts...)
	if err != nil {
		return nil, fmt.Errorf("failed to build TLS config for CA cert %q: %w", caCertPath, err)
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
