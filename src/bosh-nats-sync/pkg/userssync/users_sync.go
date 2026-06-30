package userssync

import (
	"bytes"
	"context"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"strings"
	"sync"
	"syscall"
	"time"

	"bosh-nats-sync/pkg/authprovider"
	"bosh-nats-sync/pkg/config"
	"bosh-nats-sync/pkg/natsauthconfig"
)

const (
	defaultDirectorConnectionWaitTimeout   = 60
	defaultDirectorConnectionRetryInterval = 1 * time.Second
	// httpClientTimeout bounds a single director API request.
	// Intentionally matches authprovider.httpClientTimeout (UAA token request).
	httpClientTimeout = 30 * time.Second
)

type CommandRunner func(executable string, args ...string) ([]byte, error)

func DefaultCommandRunner(executable string, args ...string) ([]byte, error) {
	cmd := exec.Command(executable, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return output, fmt.Errorf("cannot execute: %s %s, Error: %s: %w", executable, strings.Join(args, " "), string(output), err)
	}
	return output, nil
}

type UsersSync struct {
	natsConfigFilePath   string
	boshConfig           config.DirectorConfig
	natsServerExecutable string
	natsServerPIDFile    string
	logger               *slog.Logger
	commandRunner        CommandRunner

	// clientOnce guards lazy, one-time construction of the director HTTP
	// client so that the *http.Transport (and its connection pool and CA
	// trust store) is reused across every request and every sync tick rather
	// than rebuilt per request.
	clientOnce sync.Once
	client     *http.Client
	clientErr  error
}

// NewUsersSync builds a UsersSync from the parsed config. The runner uses this
// for both the bootstrap and the periodic sync so the wiring lives in one place.
func NewUsersSync(cfg *config.Config, logger *slog.Logger, cmdRunner CommandRunner) *UsersSync {
	return &UsersSync{
		natsConfigFilePath:   cfg.NATS.ConfigFilePath,
		boshConfig:           cfg.Director,
		natsServerExecutable: cfg.NATS.NATSServerExecutable,
		natsServerPIDFile:    cfg.NATS.NATSServerPIDFile,
		logger:               logger,
		commandRunner:        cmdRunner,
	}
}

func (u *UsersSync) getCommandRunner() CommandRunner {
	if u.commandRunner != nil {
		return u.commandRunner
	}
	return DefaultCommandRunner
}

func (u *UsersSync) Execute(ctx context.Context) error {
	u.logger.Info("Executing NATS Users Synchronization")

	var vms []natsauthconfig.VM
	overwriteableConfigFile := true

	// Wait for the director to be reachable and, on success, build a single
	// AuthProvider from the /info response. The provider is reused for every
	// authenticated request in this pass, so /info is fetched once and (for a
	// UAA director) a token is minted once per sync rather than per request.
	provider, err := u.withDirectorConnection(ctx)
	if err == nil {
		vms, err = u.queryAllRunningVMs(ctx, provider)
	}

	if err != nil {
		// Context cancellation means graceful shutdown is in progress — skip this
		// sync pass cleanly rather than logging a misleading VM-query error.
		if ctx.Err() != nil {
			return nil
		}
		// Intentional behavioural difference from the Ruby implementation:
		// Ruby raised ECONNREFUSED after exhausting retries, which caused the
		// process to exit and BPM to restart it. Go instead logs the error and
		// falls back to writing a director/HM-only config if auth.json is empty,
		// giving health_monitor a chance to authenticate against NATS while the
		// director is still starting up. This improves startup reliability by
		// avoiding the crash-restart loop on a slow director start.
		u.logger.Error("Could not query all running vms", "error", err)
		overwriteableConfigFile = u.userFileOverwritable()
		if overwriteableConfigFile {
			u.logger.Info("NATS config file is empty, writing basic users config file.")
		} else {
			u.logger.Info("NATS config file is not empty, doing nothing.")
		}
	} else {
		// Count VMs that have a valid agent_id (empty-agent_id VMs are skipped by
		// CreateConfig; logging both totals helps diagnose transient null-agent_id
		// windows during NATS credential rotation).
		registered := 0
		for _, vm := range vms {
			if vm.AgentID != "" {
				registered++
			}
		}
		u.logger.Info("Queried director for VMs", "total", len(vms), "registered", registered)
	}

	if overwriteableConfigFile {
		currentFileHash := u.natsFileHash()

		directorSubject := readSubjectFile(u.boshConfig.DirectorSubjectFile)
		hmSubject := readSubjectFile(u.boshConfig.HMSubjectFile)

		newFileHash, writeErr := u.writeNATSConfigFile(vms, directorSubject, hmSubject)
		if writeErr != nil {
			return writeErr
		}

		if currentFileHash != newFileHash {
			u.logger.Info("NATS config changed, reloading NATS server")
			if reloadErr := ReloadNATSServerConfig(u.natsServerExecutable, u.natsServerPIDFile, u.getCommandRunner()); reloadErr != nil {
				return reloadErr
			}
		}
	}

	u.logger.Info("Finishing NATS Users Synchronization")
	return nil
}

func ReloadNATSServerConfig(executable, pidFile string, runner CommandRunner) error {
	arg := fmt.Sprintf("reload=%s", pidFile)
	_, err := runner(executable, "--signal", arg)
	return err
}

// Bootstrap writes the initial NATS authorization config with only the
// director and health-monitor subjects read from their subject files on disk.
// It is called once at startup before the periodic sync loop so that
// health_monitor and the director can authenticate against NATS immediately,
// without waiting for bosh_nats_sync to successfully query the director API.
//
// Bootstrap is intentionally a no-op if auth.json already contains real user
// entries.  This can happen when bosh-nats-sync is restarted mid-flight (e.g.
// after a sync error) while agent credentials are already in place.
// Overwriting auth.json with only director/HM credentials in that situation
// would remove the agent entries and prevent rebooting VMs from reconnecting
// to NATS until the next successful full sync.
func (u *UsersSync) Bootstrap() error {
	directorSubject := readSubjectFile(u.boshConfig.DirectorSubjectFile)
	hmSubject := readSubjectFile(u.boshConfig.HMSubjectFile)

	if directorSubject == nil && hmSubject == nil {
		u.logger.Info("Bootstrap: no subject files found, skipping initial NATS config write")
		return nil
	}

	if u.hasExistingUsers() {
		u.logger.Info("Bootstrap: NATS config already contains users, skipping overwrite to preserve agent credentials")
		return nil
	}

	u.logger.Info("Bootstrap: writing initial NATS config with director/HM subjects")
	if _, err := u.writeNATSConfigFile(nil, directorSubject, hmSubject); err != nil {
		return fmt.Errorf("bootstrap: failed to write NATS config: %w", err)
	}
	if err := ReloadNATSServerConfig(u.natsServerExecutable, u.natsServerPIDFile, u.getCommandRunner()); err != nil {
		return fmt.Errorf("bootstrap: failed to reload NATS server config: %w", err)
	}
	u.logger.Info("Bootstrap: NATS config written and server reloaded")
	return nil
}

// hasExistingUsers reports whether auth.json already contains at least one
// real user entry.  Used by Bootstrap to avoid overwriting agent credentials
// that were populated by a previous Execute call.
func (u *UsersSync) hasExistingUsers() bool {
	data, err := os.ReadFile(u.natsConfigFilePath)
	if err != nil {
		return false
	}
	var cfg natsauthconfig.AuthorizationConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return false
	}
	return len(cfg.Authorization.Users) > 0
}

// withDirectorConnection polls the director's unauthenticated /info endpoint
// until it responds or the connection_wait_timeout deadline elapses, retrying
// only on connection-class errors. On success it parses /info and returns a
// single AuthProvider for the caller to reuse across all authenticated requests
// in this sync pass.
func (u *UsersSync) withDirectorConnection(ctx context.Context) (*authprovider.AuthProvider, error) {
	timeout := u.boshConfig.ConnectionWaitTimeout
	if timeout <= 0 {
		timeout = defaultDirectorConnectionWaitTimeout
	}
	deadline := time.Now().Add(time.Duration(timeout) * time.Second)

	var lastErr error
	for attempt := 1; ; attempt++ {
		infoBody, err := u.boshAPIResponseBody(ctx, "/info", nil)
		if err == nil {
			info, parseErr := authprovider.ParseInfoResponse(infoBody)
			if parseErr != nil {
				return nil, parseErr
			}
			return authprovider.New(info, u.boshConfig, u.logger), nil
		}

		lastErr = err
		if !isConnectionError(err) {
			return nil, err
		}

		u.logger.Info("Waiting for director API to become available", "attempt", attempt, "error", err)

		// Stop if the next retry interval would exceed the deadline.
		if !time.Now().Add(defaultDirectorConnectionRetryInterval).Before(deadline) {
			return nil, lastErr
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(defaultDirectorConnectionRetryInterval):
		}
	}
}

// isConnectionError reports whether err is a transient connection-class failure
// worth retrying, mirroring the Ruby DIRECTOR_CONNECTION_ERRORS list
// (ECONNREFUSED, ECONNRESET, ETIMEDOUT, EHOSTUNREACH, ENETUNREACH,
// Net::OpenTimeout, Net::ReadTimeout, SocketError). It classifies by error type
// via errors.Is/errors.As rather than matching message text, so HTTP status
// errors (which carry no network error type) are never misclassified.
func isConnectionError(err error) bool {
	if err == nil {
		return false
	}

	// Connect/read timeouts surfaced via the http.Client Timeout or a context
	// deadline (Ruby Net::OpenTimeout / Net::ReadTimeout).
	if errors.Is(err, context.DeadlineExceeded) {
		return true
	}
	// Server closed the connection mid-response (Ruby Errno::ECONNRESET / EOF).
	if errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF) {
		return true
	}
	// Socket-level errors (Ruby Errno::* family).
	for _, errno := range []syscall.Errno{
		syscall.ECONNREFUSED, syscall.ECONNRESET, syscall.ETIMEDOUT,
		syscall.EHOSTUNREACH, syscall.ENETUNREACH, syscall.EPIPE,
	} {
		if errors.Is(err, errno) {
			return true
		}
	}
	// DNS resolution failure (Ruby SocketError).
	var dnsErr *net.DNSError
	if errors.As(err, &dnsErr) {
		return true
	}
	// Any remaining network timeout (e.g. wrapped url.Error reporting Timeout()).
	var netErr net.Error
	if errors.As(err, &netErr) && netErr.Timeout() {
		return true
	}
	// Catch-all for low-level network operation errors (dial, read, write).
	// Note: TLS certificate verification errors (x509.UnknownAuthorityError etc.)
	// are NOT wrapped in *net.OpError by Go's HTTP client — they fall through this
	// function and are correctly treated as non-retryable.
	var opErr *net.OpError
	return errors.As(err, &opErr)
}

// userFileOverwritable mirrors the Ruby usable_director_ca_cert? semantics:
// it returns true (safe to overwrite) only when the file cannot be read,
// cannot be parsed, or contains a completely empty JSON object ("{}").
//
// Note: this intentionally differs from hasExistingUsers, which checks whether
// the authorization.users array is populated. userFileOverwritable is the
// Execute-time gate ("should we write at all?"); hasExistingUsers is the
// Bootstrap-time gate ("should we overwrite agent credentials?").
func (u *UsersSync) userFileOverwritable() bool {
	data, err := os.ReadFile(u.natsConfigFilePath)
	if err != nil {
		return true
	}
	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		return true
	}
	return len(parsed) == 0
}

func readSubjectFile(filePath string) *string {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil
	}
	s := strings.TrimSpace(string(data))
	if s == "" {
		return nil
	}
	return &s
}

func (u *UsersSync) natsFileHash() string {
	data, err := os.ReadFile(u.natsConfigFilePath)
	if err != nil {
		return ""
	}
	return hashBytes(data)
}

func hashBytes(data []byte) string {
	return fmt.Sprintf("%x", sha256.Sum256(data))
}

// boshAPIResponseBody issues a GET against the director. When provider is
// non-nil the request carries an Authorization header obtained from it.
func (u *UsersSync) boshAPIResponseBody(ctx context.Context, apiPath string, provider *authprovider.AuthProvider) ([]byte, error) {
	client, err := u.httpClient()
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.boshConfig.URL+apiPath, nil)
	if err != nil {
		return nil, err
	}

	if provider != nil {
		header, err := provider.AuthHeader(ctx)
		if err != nil {
			return nil, err
		}
		if header != "" {
			req.Header.Set("Authorization", header)
		}
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer func() { _ = resp.Body.Close() }()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("cannot access: %s, Status Code: %d, %s", apiPath, resp.StatusCode, string(body))
	}

	return body, nil
}

// httpClient lazily builds and caches the director HTTP client so its transport
// (connection pool + CA trust store) is reused for the lifetime of the process.
// If buildHTTPClient fails (e.g., invalid CA cert file), the error is permanent:
// sync.Once guarantees Do is not retried, which is intentional — CA-cert
// misconfiguration requires operator intervention and a process restart to fix.
func (u *UsersSync) httpClient() (*http.Client, error) {
	u.clientOnce.Do(func() {
		u.client, u.clientErr = u.buildHTTPClient()
	})
	return u.client, u.clientErr
}

// buildHTTPClient mirrors the Ruby NATSSync::UsersSync HTTP client: TLS peer
// verification is always on, and director_ca_cert is used as the trust root
// when the file exists and has non-empty content; otherwise the system trust
// store is used. A configured-but-unparseable cert is a hard error rather than
// a silent fallback to the system store.
func (u *UsersSync) buildHTTPClient() (*http.Client, error) {
	tlsCfg := &tls.Config{MinVersion: tls.VersionTLS12}
	pool, err := u.directorCACertPool()
	if err != nil {
		return nil, err
	}
	if pool != nil {
		tlsCfg.RootCAs = pool
	}
	return &http.Client{
		Transport: &http.Transport{TLSClientConfig: tlsCfg},
		Timeout:   httpClientTimeout,
	}, nil
}

// directorCACertPool returns the CA pool built from director_ca_cert, or nil to
// signal "use the system trust store". It returns nil (system store) when the
// cert is not configured, missing/unreadable, or empty — matching the Ruby
// usable_director_ca_cert? predicate — but returns an error when a configured
// file contains no parseable certificate.
func (u *UsersSync) directorCACertPool() (*x509.CertPool, error) {
	certPath := u.boshConfig.DirectorCACert
	if certPath == "" {
		return nil, nil
	}
	data, err := os.ReadFile(certPath)
	if err != nil || len(strings.TrimSpace(string(data))) == 0 {
		return nil, nil
	}
	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM(data) {
		return nil, fmt.Errorf("director_ca_cert %q contains no valid certificates", certPath)
	}
	return pool, nil
}

type deployment struct {
	Name string `json:"name"`
}

func (u *UsersSync) queryAllDeployments(ctx context.Context, provider *authprovider.AuthProvider) ([]string, error) {
	body, err := u.boshAPIResponseBody(ctx, "/deployments", provider)
	if err != nil {
		return nil, err
	}

	var deployments []deployment
	if err := json.Unmarshal(body, &deployments); err != nil {
		return nil, err
	}

	names := make([]string, len(deployments))
	for i, d := range deployments {
		names[i] = d.Name
	}
	return names, nil
}

func (u *UsersSync) getVMsByDeployment(ctx context.Context, provider *authprovider.AuthProvider, deploymentName string) ([]natsauthconfig.VM, error) {
	body, err := u.boshAPIResponseBody(ctx, "/deployments/"+url.PathEscape(deploymentName)+"/vms", provider)
	if err != nil {
		return nil, err
	}

	var vms []natsauthconfig.VM
	if err := json.Unmarshal(body, &vms); err != nil {
		return nil, err
	}
	return vms, nil
}

func (u *UsersSync) queryAllRunningVMs(ctx context.Context, provider *authprovider.AuthProvider) ([]natsauthconfig.VM, error) {
	deploymentNames, err := u.queryAllDeployments(ctx, provider)
	if err != nil {
		return nil, err
	}

	var allVMs []natsauthconfig.VM
	for _, name := range deploymentNames {
		vms, err := u.getVMsByDeployment(ctx, provider, name)
		if err != nil {
			return nil, err
		}
		allVMs = append(allVMs, vms...)
	}
	return allVMs, nil
}

// writeNATSConfigFile serialises cfg and writes it to disk. It returns the
// sha256 hash of the bytes written so that callers can compare with the
// pre-write hash without a second disk read.
func (u *UsersSync) writeNATSConfigFile(vms []natsauthconfig.VM, directorSubject, hmSubject *string) (string, error) {
	cfg := natsauthconfig.CreateConfig(vms, directorSubject, hmSubject)
	// Use SetEscapeHTML(false) so that '>' in NATS subjects (e.g. "director.>")
	// is written literally rather than as the \u003e Unicode escape that
	// json.Marshal emits by default.  NATS's config parser does not support \u
	// escapes and rejects the file with a parse error if they are present.
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(cfg); err != nil {
		return "", err
	}
	// Encode appends a trailing newline; strip it for a consistent on-disk format.
	data := bytes.TrimRight(buf.Bytes(), "\n")
	if err := os.WriteFile(u.natsConfigFilePath, data, 0644); err != nil {
		return "", err
	}
	return hashBytes(data), nil
}
