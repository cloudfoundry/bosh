package authprovider_test

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"log/slog"
	"math/big"
	"net/http"
	"net/http/httptest"
	"os"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bosh-nats-sync/pkg/authprovider"
	"bosh-nats-sync/pkg/config"
)

// generateTestCACertPEM creates a minimal self-signed CA certificate PEM for use in tests.
func generateTestCACertPEM() []byte {
	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		panic(err)
	}
	tmpl := &x509.Certificate{
		SerialNumber:          big.NewInt(1),
		Subject:               pkix.Name{CommonName: "test-ca"},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().Add(10 * 365 * 24 * time.Hour),
		IsCA:                  true,
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageCRLSign,
		BasicConstraintsValid: true,
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &priv.PublicKey, priv)
	if err != nil {
		panic(err)
	}
	return pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der})
}

var _ = Describe("AuthProvider", func() {
	var logger *slog.Logger

	BeforeEach(func() {
		logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))
	})

	Context("when director is in UAA mode", func() {
		var (
			uaaServer    *httptest.Server
			tokenCounter int
			expiresIn    int
		)

		BeforeEach(func() {
			tokenCounter = 0
			expiresIn = 3600
		})

		JustBeforeEach(func() {
			uaaServer = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				tokenCounter++
				w.Header().Set("Content-Type", "application/json")
				resp := map[string]interface{}{
					"access_token": fmt.Sprintf("token-%d", tokenCounter),
					"token_type":   "bearer",
					"expires_in":   expiresIn,
				}
				json.NewEncoder(w).Encode(resp)
			}))
		})

		AfterEach(func() {
			if uaaServer != nil {
				uaaServer.Close()
			}
		})

		It("returns auth header provided by UAA", func() {
			info := authprovider.InfoResponse{
				UserAuthentication: &authprovider.UserAuthentication{
					Type:    "uaa",
					Options: authprovider.UAAOptions{URL: uaaServer.URL},
				},
			}
			cfg := config.DirectorConfig{
				ClientID:     "fake-client",
				ClientSecret: "fake-client-secret",
			}
			provider := authprovider.New(info, cfg, logger)

			header, err := provider.AuthHeader(context.Background())
			Expect(err).NotTo(HaveOccurred())
			Expect(header).To(Equal("Bearer token-1"))
		})

		It("reuses the same token for subsequent requests", func() {
			info := authprovider.InfoResponse{
				UserAuthentication: &authprovider.UserAuthentication{
					Type:    "uaa",
					Options: authprovider.UAAOptions{URL: uaaServer.URL},
				},
			}
			cfg := config.DirectorConfig{
				ClientID:     "fake-client",
				ClientSecret: "fake-client-secret",
			}
			provider := authprovider.New(info, cfg, logger)

			header1, err := provider.AuthHeader(context.Background())
			Expect(err).NotTo(HaveOccurred())
			header2, err := provider.AuthHeader(context.Background())
			Expect(err).NotTo(HaveOccurred())
			Expect(header1).To(Equal(header2))
			Expect(tokenCounter).To(Equal(1))
		})

		Context("when token is about to expire", func() {
			BeforeEach(func() {
				expiresIn = 30
			})

			It("obtains a new token", func() {
				info := authprovider.InfoResponse{
					UserAuthentication: &authprovider.UserAuthentication{
						Type:    "uaa",
						Options: authprovider.UAAOptions{URL: uaaServer.URL},
					},
				}
				cfg := config.DirectorConfig{
					ClientID:     "fake-client",
					ClientSecret: "fake-client-secret",
				}
				provider := authprovider.New(info, cfg, logger)

				header1, err := provider.AuthHeader(context.Background())
				Expect(err).NotTo(HaveOccurred())
				Expect(header1).To(Equal("Bearer token-1"))

				header2, err := provider.AuthHeader(context.Background())
				Expect(err).NotTo(HaveOccurred())
				Expect(header2).To(Equal("Bearer token-2"))
			})
		})

		Context("when getting token fails", func() {
			It("returns an error so callers can handle transient auth failures", func() {
				info := authprovider.InfoResponse{
					UserAuthentication: &authprovider.UserAuthentication{
						Type:    "uaa",
						Options: authprovider.UAAOptions{URL: "http://127.0.0.1:1"},
					},
				}
				cfg := config.DirectorConfig{
					ClientID:     "fake-client",
					ClientSecret: "fake-client-secret",
				}
				provider := authprovider.New(info, cfg, logger)

				header, err := provider.AuthHeader(context.Background())
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to obtain token from UAA"))
				Expect(header).To(BeEmpty())
			})
		})

		Context("with director_ca_cert file", func() {
			It("uses the director_ca_cert when the file exists and is non-empty", func() {
				tmpFile, err := os.CreateTemp("", "director_ca_cert_*.pem")
				Expect(err).NotTo(HaveOccurred())
				defer os.Remove(tmpFile.Name())
				_, err = tmpFile.Write(generateTestCACertPEM())
				Expect(err).NotTo(HaveOccurred())
				Expect(tmpFile.Close()).To(Succeed())

				info := authprovider.InfoResponse{
					UserAuthentication: &authprovider.UserAuthentication{
						Type:    "uaa",
						Options: authprovider.UAAOptions{URL: uaaServer.URL},
					},
				}
				cfg := config.DirectorConfig{
					ClientID:       "fake-client",
					ClientSecret:   "fake-client-secret",
					DirectorCACert: tmpFile.Name(),
				}
				provider := authprovider.New(info, cfg, logger)

				header, err := provider.AuthHeader(context.Background())
				Expect(err).NotTo(HaveOccurred())
				Expect(header).To(HavePrefix("Bearer "))
			})
		})

		Context("CA file selection between director_ca_cert and uaa_ca_cert", func() {
			var (
				dirCertPath  string
				uaaCertPath  string
				validCertPEM []byte
			)

			BeforeEach(func() {
				validCertPEM = generateTestCACertPEM()

				dirFile, err := os.CreateTemp("", "director_ca_cert_*.pem")
				Expect(err).NotTo(HaveOccurred())
				_, err = dirFile.Write(validCertPEM)
				Expect(err).NotTo(HaveOccurred())
				Expect(dirFile.Close()).To(Succeed())
				dirCertPath = dirFile.Name()

				uaaFile, err := os.CreateTemp("", "uaa_ca_cert_*.pem")
				Expect(err).NotTo(HaveOccurred())
				Expect(uaaFile.Close()).To(Succeed())
				uaaCertPath = uaaFile.Name()
			})

			AfterEach(func() {
				_ = os.Remove(dirCertPath)
				_ = os.Remove(uaaCertPath)
			})

			It("prefers uaa_ca_cert when the file exists and has non-empty content", func() {
				Expect(os.WriteFile(uaaCertPath, validCertPEM, 0o600)).To(Succeed())

				info := authprovider.InfoResponse{
					UserAuthentication: &authprovider.UserAuthentication{
						Type:    "uaa",
						Options: authprovider.UAAOptions{URL: uaaServer.URL},
					},
				}
				cfg := config.DirectorConfig{
					ClientID:       "fake-client",
					ClientSecret:   "fake-client-secret",
					DirectorCACert: dirCertPath,
					UAACACert:      uaaCertPath,
				}
				provider := authprovider.New(info, cfg, logger)

				Expect(provider.CAFilePath()).To(Equal(uaaCertPath))

				header, err := provider.AuthHeader(context.Background())
				Expect(err).NotTo(HaveOccurred())
				Expect(header).To(HavePrefix("Bearer "))
			})

			It("falls back to director_ca_cert when uaa_ca_cert file is empty", func() {
				Expect(os.WriteFile(uaaCertPath, []byte("  \n"), 0o600)).To(Succeed())

				info := authprovider.InfoResponse{
					UserAuthentication: &authprovider.UserAuthentication{
						Type:    "uaa",
						Options: authprovider.UAAOptions{URL: uaaServer.URL},
					},
				}
				cfg := config.DirectorConfig{
					ClientID:       "fake-client",
					ClientSecret:   "fake-client-secret",
					DirectorCACert: dirCertPath,
					UAACACert:      uaaCertPath,
				}
				provider := authprovider.New(info, cfg, logger)

				Expect(provider.CAFilePath()).To(Equal(dirCertPath))
			})

			It("falls back to director_ca_cert when uaa_ca_cert file is missing", func() {
				Expect(os.Remove(uaaCertPath)).To(Succeed())

				info := authprovider.InfoResponse{
					UserAuthentication: &authprovider.UserAuthentication{
						Type:    "uaa",
						Options: authprovider.UAAOptions{URL: uaaServer.URL},
					},
				}
				cfg := config.DirectorConfig{
					ClientID:       "fake-client",
					ClientSecret:   "fake-client-secret",
					DirectorCACert: dirCertPath,
					UAACACert:      uaaCertPath,
				}
				provider := authprovider.New(info, cfg, logger)

				Expect(provider.CAFilePath()).To(Equal(dirCertPath))
			})
		})

		// Mirrors Ruby spec: 'user has not provided director_ca_cert'
		// When neither director_ca_cert nor uaa_ca_cert is set, CAFilePath() returns ""
		// and buildHTTPClient sets tls.Config{RootCAs: nil}, which makes Go use the
		// system trust store — the equivalent of Ruby's
		// OpenSSL::X509::Store.new.tap(&:set_default_paths).
		Context("when no CA cert is provided (system trust store)", func() {
			makeInfo := func() authprovider.InfoResponse {
				return authprovider.InfoResponse{
					UserAuthentication: &authprovider.UserAuthentication{
						Type:    "uaa",
						Options: authprovider.UAAOptions{URL: uaaServer.URL},
					},
				}
			}
			makeCfg := func() config.DirectorConfig {
				return config.DirectorConfig{
					ClientID:     "fake-client",
					ClientSecret: "fake-client-secret",
					// No DirectorCACert or UAACACert configured.
				}
			}

			It("CAFilePath returns an empty string, indicating the system trust store will be used", func() {
				provider := authprovider.New(makeInfo(), makeCfg(), logger)
				Expect(provider.CAFilePath()).To(BeEmpty())
			})

			It("returns auth header provided by UAA", func() {
				provider := authprovider.New(makeInfo(), makeCfg(), logger)

				header, err := provider.AuthHeader(context.Background())
				Expect(err).NotTo(HaveOccurred())
				Expect(header).To(Equal("Bearer token-1"))
			})

			It("reuses the same token for subsequent requests", func() {
				provider := authprovider.New(makeInfo(), makeCfg(), logger)

				header1, err := provider.AuthHeader(context.Background())
				Expect(err).NotTo(HaveOccurred())
				header2, err := provider.AuthHeader(context.Background())
				Expect(err).NotTo(HaveOccurred())
				Expect(header1).To(Equal(header2))
				Expect(tokenCounter).To(Equal(1))
			})

			Context("when token is about to expire", func() {
				BeforeEach(func() {
					expiresIn = 30
				})

				It("obtains a new token", func() {
					provider := authprovider.New(makeInfo(), makeCfg(), logger)

					header1, err := provider.AuthHeader(context.Background())
					Expect(err).NotTo(HaveOccurred())
					Expect(header1).To(Equal("Bearer token-1"))

					header2, err := provider.AuthHeader(context.Background())
					Expect(err).NotTo(HaveOccurred())
					Expect(header2).To(Equal("Bearer token-2"))
				})
			})

			Context("when getting token fails", func() {
				It("returns an error", func() {
					info := authprovider.InfoResponse{
						UserAuthentication: &authprovider.UserAuthentication{
							Type:    "uaa",
							Options: authprovider.UAAOptions{URL: "http://127.0.0.1:1"},
						},
					}
					provider := authprovider.New(info, makeCfg(), logger)

					header, err := provider.AuthHeader(context.Background())
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("failed to obtain token from UAA"))
					Expect(header).To(BeEmpty())
				})
			})

			// Stronger than the Ruby test: verifies that the HTTP client built for
			// UAA token requests does NOT use InsecureSkipVerify. When no CA cert is
			// configured the client uses tls.Config{RootCAs: nil} (system trust store),
			// so a self-signed test-server cert that isn't in the system store must
			// cause a TLS error — not silently succeed.
			It("does not skip TLS verification when connecting to a TLS UAA server", func() {
				tlsUAAServer := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					w.Header().Set("Content-Type", "application/json")
					fmt.Fprint(w, `{"access_token":"tls-token","token_type":"bearer","expires_in":3600}`)
				}))
				defer tlsUAAServer.Close()

				info := authprovider.InfoResponse{
					UserAuthentication: &authprovider.UserAuthentication{
						Type:    "uaa",
						Options: authprovider.UAAOptions{URL: tlsUAAServer.URL},
					},
				}
				provider := authprovider.New(info, makeCfg(), logger)

				_, err := provider.AuthHeader(context.Background())
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to obtain token from UAA"))
			})
		})
	})

	Context("when director is in non-UAA mode", func() {
		It("returns Basic authentication string with username and password", func() {
			info := authprovider.InfoResponse{}
			cfg := config.DirectorConfig{
				User:     "fake-user",
				Password: "secret-password",
			}
			provider := authprovider.New(info, cfg, logger)

			header, err := provider.AuthHeader(context.Background())
			Expect(err).NotTo(HaveOccurred())

			expected := "Basic " + base64.StdEncoding.EncodeToString([]byte("fake-user:secret-password"))
			Expect(header).To(Equal(expected))
		})
	})

	Describe("ParseInfoResponse", func() {
		It("parses a valid info JSON response", func() {
			body := []byte(`{
				"user_authentication": {
					"type": "uaa",
					"options": {"url": "https://uaa.example.com"}
				}
			}`)
			info, err := authprovider.ParseInfoResponse(body)
			Expect(err).NotTo(HaveOccurred())
			Expect(info.UserAuthentication).NotTo(BeNil())
			Expect(info.UserAuthentication.Type).To(Equal("uaa"))
			Expect(info.UserAuthentication.Options.URL).To(Equal("https://uaa.example.com"))
		})

		It("handles missing user_authentication", func() {
			body := []byte(`{"name": "bosh-lite"}`)
			info, err := authprovider.ParseInfoResponse(body)
			Expect(err).NotTo(HaveOccurred())
			Expect(info.UserAuthentication).To(BeNil())
		})
	})
})

var _ = Describe("Token expiration deadline", func() {
	It("is 60 seconds", func() {
		Expect(authprovider.ExpirationDeadline).To(Equal(60 * time.Second))
	})
})
