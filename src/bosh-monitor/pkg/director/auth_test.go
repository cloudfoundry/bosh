package director_test

// Tests for the AuthProvider UAA token flow and CA cert selection logic.
//
// Ruby equivalents: spec/unit/bosh/monitor/auth_provider_spec.rb
//
// Approach:
//   • "CA cert path selection" tests call director.UaaCACertPath directly
//     (exposed via export_test.go) against real temp files, mirroring the
//     five Ruby contexts that control which ssl_ca_file the CF::UAA::TokenIssuer
//     receives.
//   • "token lifecycle" tests drive AuthProvider.AuthHeader against a plain
//     HTTP httptest.Server acting as a fake UAA /oauth/token endpoint.  TLS
//     is not needed here because the CA cert only affects which roots are
//     trusted; the functional token-caching/expiry/error behaviour is identical
//     regardless of CA cert selection.

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/director"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("AuthProvider — UAA mode", func() {
	var (
		uaaServer    *httptest.Server
		tokenCounter int
		expiresIn    int
		serverErr    bool

		logBuf bytes.Buffer
		logger *slog.Logger

		tmpDir string
	)

	BeforeEach(func() {
		tokenCounter = 0
		expiresIn = 3600 // long-lived by default
		serverErr = false
		logBuf.Reset()
		logger = slog.New(slog.NewTextHandler(&logBuf, &slog.HandlerOptions{Level: slog.LevelDebug}))

		uaaServer = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path != "/oauth/token" {
				w.WriteHeader(http.StatusNotFound)
				return
			}
			if serverErr {
				w.WriteHeader(http.StatusInternalServerError)
				fmt.Fprint(w, "internal server error")
				return
			}
			tokenCounter++
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]interface{}{
				"access_token": fmt.Sprintf("token-%d", tokenCounter),
				"token_type":   "bearer",
				"expires_in":   expiresIn,
			})
		}))

		var err error
		tmpDir, err = os.MkdirTemp("", "uaa-ca-test")
		Expect(err).NotTo(HaveOccurred())
	})

	AfterEach(func() {
		uaaServer.Close()
		Expect(os.RemoveAll(tmpDir)).To(Succeed())
	})

	// makeAuthInfo builds the user_authentication block pointing at the fake UAA.
	makeAuthInfo := func() map[string]interface{} {
		return map[string]interface{}{
			"user_authentication": map[string]interface{}{
				"type": "uaa",
				"options": map[string]interface{}{
					"url": uaaServer.URL,
				},
			},
		}
	}

	// writeCAFile writes content to a temp file and returns its path.
	writeCAFile := func(name, content string) string {
		path := filepath.Join(tmpDir, name)
		Expect(os.WriteFile(path, []byte(content), 0600)).To(Succeed())
		return path
	}

	// ── CA cert path selection ───────────────────────────────────────────────
	//
	// Ruby: five contexts that control which ssl_ca_file CF::UAA::TokenIssuer
	// receives.  Go tests uaaCACertPath() directly.

	Describe("CA cert path selection for UAA requests", func() {
		// Ruby: "user provides director_ca_cert"
		// When only director_ca_cert is set, it is used for UAA requests.
		It("uses director_ca_cert when only director_ca_cert is configured", func() {
			dirCAPath := writeCAFile("dir.pem", "fake-director-ca-pem")
			config := map[string]interface{}{
				"client_id":        "fake-client",
				"client_secret":    "fake-secret",
				"director_ca_cert": dirCAPath,
				"uaa_ca_cert":      "",
			}
			ap := director.NewAuthProvider(makeAuthInfo(), config, logger)
			Expect(director.UaaCACertPath(ap)).To(Equal(dirCAPath))
		})

		// Ruby: "user provides uaa_ca_cert with a non-empty file"
		// uaa_ca_cert takes priority over director_ca_cert when it has content.
		It("prefers uaa_ca_cert when it points to a non-empty file", func() {
			dirCAPath := writeCAFile("dir.pem", "fake-director-ca-pem")
			uaaCAPath := writeCAFile("uaa.pem", "fake-uaa-ca-pem")
			config := map[string]interface{}{
				"client_id":        "fake-client",
				"client_secret":    "fake-secret",
				"director_ca_cert": dirCAPath,
				"uaa_ca_cert":      uaaCAPath,
			}
			ap := director.NewAuthProvider(makeAuthInfo(), config, logger)
			Expect(director.UaaCACertPath(ap)).To(Equal(uaaCAPath))
		})

		// Ruby: "user provides uaa_ca_cert but file is empty"
		// An empty uaa_ca_cert file is treated as not provided; fall back to
		// director_ca_cert.
		It("falls back to director_ca_cert when uaa_ca_cert file is empty", func() {
			dirCAPath := writeCAFile("dir.pem", "fake-director-ca-pem")
			emptyCAPath := writeCAFile("uaa-empty.pem", "   \n")
			config := map[string]interface{}{
				"client_id":        "fake-client",
				"client_secret":    "fake-secret",
				"director_ca_cert": dirCAPath,
				"uaa_ca_cert":      emptyCAPath,
			}
			ap := director.NewAuthProvider(makeAuthInfo(), config, logger)
			Expect(director.UaaCACertPath(ap)).To(Equal(dirCAPath))
		})

		// Ruby: "user provides uaa_ca_cert but file is missing"
		// A missing uaa_ca_cert file is treated as not provided; fall back to
		// director_ca_cert.
		It("falls back to director_ca_cert when uaa_ca_cert file does not exist", func() {
			dirCAPath := writeCAFile("dir.pem", "fake-director-ca-pem")
			config := map[string]interface{}{
				"client_id":        "fake-client",
				"client_secret":    "fake-secret",
				"director_ca_cert": dirCAPath,
				"uaa_ca_cert":      filepath.Join(tmpDir, "no-such-uaa-ca.pem"),
			}
			ap := director.NewAuthProvider(makeAuthInfo(), config, logger)
			Expect(director.UaaCACertPath(ap)).To(Equal(dirCAPath))
		})

		// Ruby: "user has not provided director_ca_cert"
		// When neither cert is configured, the path is empty, meaning the
		// system trust store is used (Go: tls.Config{RootCAs: nil}).
		It("returns an empty string (system trust store) when neither cert is configured", func() {
			config := map[string]interface{}{
				"client_id":     "fake-client",
				"client_secret": "fake-secret",
			}
			ap := director.NewAuthProvider(makeAuthInfo(), config, logger)
			Expect(director.UaaCACertPath(ap)).To(BeEmpty())
		})
	})

	// ── Token lifecycle (Ruby shared_examples :auth_provider_shared_tests) ───
	//
	// These cover the four shared examples that Ruby runs in each CA cert
	// context.  Because we use a plain-HTTP fake server the CA cert path
	// does not affect the outcome; CA-cert selection is verified separately
	// above.

	Describe("token lifecycle", func() {
		var ap *director.AuthProvider

		BeforeEach(func() {
			ap = director.NewAuthProvider(makeAuthInfo(), map[string]interface{}{
				"client_id":     "fake-client",
				"client_secret": "fake-client-secret",
			}, logger)
		})

		// Ruby shared example: "returns auth header provided by UAA"
		It("returns a Bearer token header from UAA", func() {
			header := ap.AuthHeader()
			Expect(header).To(Equal("Bearer token-1"))
		})

		// Ruby shared example: "reuses the same token for subsequent requests"
		It("reuses the cached token for subsequent calls", func() {
			header1 := ap.AuthHeader()
			header2 := ap.AuthHeader()

			Expect(header1).To(Equal("Bearer token-1"))
			Expect(header2).To(Equal("Bearer token-1")) // same token
			Expect(tokenCounter).To(Equal(1))           // UAA called only once
		})

		// Ruby shared example: "when token is about to expire / obtains new token"
		// Ruby uses expiration_time = Time.now.to_i + 50 (50 s < 60 s threshold).
		// Go: time.Until(expiresAt) > 60s must be false, so expires_in <= 60.
		Context("when the token is about to expire", func() {
			BeforeEach(func() {
				expiresIn = 50 // 50 s < 60 s grace period → treated as expired
			})

			It("fetches a new token on the next call", func() {
				header1 := ap.AuthHeader()
				Expect(header1).To(Equal("Bearer token-1"))

				header2 := ap.AuthHeader()
				Expect(header2).To(Equal("Bearer token-2")) // new token
				Expect(tokenCounter).To(Equal(2))
			})
		})

		// Ruby shared example: "when getting token fails / logs an error"
		Context("when getting the token fails", func() {
			BeforeEach(func() {
				serverErr = true
			})

			// Ruby: expect(logger).to receive(:error).with(/failed/)
			It("logs an error", func() {
				ap.AuthHeader()
				Expect(logBuf.String()).To(ContainSubstring("Failed to obtain token from UAA"))
			})

			// Ruby: expect { auth_provider.auth_header }.to_not raise_error
			It("returns an empty string and does not panic", func() {
				Expect(func() {
					header := ap.AuthHeader()
					Expect(header).To(BeEmpty())
				}).NotTo(Panic())
			})
		})
	})
})

// ── Basic auth (already partially covered; included for completeness) ─────────

var _ = Describe("AuthProvider — non-UAA (basic auth) mode", func() {
	// Ruby: "when director is in non-UAA mode / returns the basic-auth header"
	It("returns the correct Basic auth header for the configured credentials", func() {
		authInfo := map[string]interface{}{} // no user_authentication → basic mode
		config := map[string]interface{}{
			"user":     "fake-user",
			"password": "secret-password",
		}
		logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))
		ap := director.NewAuthProvider(authInfo, config, logger)

		// "ZmFrZS11c2VyOnNlY3JldC1wYXNzd29yZA==" = base64("fake-user:secret-password")
		Expect(ap.AuthHeader()).To(Equal("Basic ZmFrZS11c2VyOnNlY3JldC1wYXNzd29yZA=="))
	})
})
