package authprovider_test

import (
	"context"
	"crypto"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/rsa"
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
	"sync/atomic"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bosh-nats-sync/pkg/authprovider"
	"bosh-nats-sync/pkg/config"
)

// generateRSAKeyPair creates a 2048-bit RSA key pair for JWT signing tests.
func generateRSAKeyPair() (*rsa.PrivateKey, []byte) {
	priv, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		panic(err)
	}
	pubBytes, err := x509.MarshalPKIXPublicKey(&priv.PublicKey)
	if err != nil {
		panic(err)
	}
	pubPEM := pem.EncodeToMemory(&pem.Block{Type: "PUBLIC KEY", Bytes: pubBytes})
	return priv, pubPEM
}

// createRS256JWT builds a minimal RS256-signed JWT for use in tests.
func createRS256JWT(privKey *rsa.PrivateKey, expiresAt time.Time) string {
	return createRSAJWT(privKey, expiresAt, "RS256", crypto.SHA256)
}

// createRSAJWT builds a minimal JWT signed with the given RSASSA-PKCS1-v1.5
// algorithm/hash pair, for use in tests covering RS256/RS384/RS512.
func createRSAJWT(privKey *rsa.PrivateKey, expiresAt time.Time, alg string, hash crypto.Hash) string {
	claimsJSON, _ := json.Marshal(map[string]interface{}{
		"sub": "test-client",
		"exp": expiresAt.Unix(),
	})
	return signRSAJWT(privKey, claimsJSON, alg, hash)
}

func signRSAJWT(privKey *rsa.PrivateKey, claimsJSON []byte, alg string, hash crypto.Hash) string {
	header := base64.RawURLEncoding.EncodeToString([]byte(fmt.Sprintf(`{"alg":%q,"typ":"JWT"}`, alg)))
	payload := base64.RawURLEncoding.EncodeToString(claimsJSON)
	sigInput := header + "." + payload
	hasher := hash.New()
	hasher.Write([]byte(sigInput))
	digest := hasher.Sum(nil)
	sig, err := rsa.SignPKCS1v15(rand.Reader, privKey, hash, digest)
	if err != nil {
		panic(err)
	}
	return sigInput + "." + base64.RawURLEncoding.EncodeToString(sig)
}

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
			uaaServer      *httptest.Server
			tokenCounter   int
			tokenExpiresAt time.Time
			firstToken     string
			secondToken    string
		)

		BeforeEach(func() {
			tokenCounter = 0
			tokenExpiresAt = time.Now().Add(time.Hour)
		})

		JustBeforeEach(func() {
			key, _ := generateRSAKeyPair()
			firstToken = createRS256JWT(key, tokenExpiresAt)
			secondToken = createRS256JWT(key, tokenExpiresAt.Add(time.Second))
			uaaServer = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				tokenCounter++
				token := firstToken
				if tokenCounter > 1 {
					token = secondToken
				}
				w.Header().Set("Content-Type", "application/json")
				resp := map[string]interface{}{
					"access_token": token,
					"token_type":   "bearer",
					"expires_in":   3600,
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
			Expect(header).To(Equal("Bearer " + firstToken))
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
				tokenExpiresAt = time.Now().Add(30 * time.Second)
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
				Expect(header1).To(Equal("Bearer " + firstToken))

				header2, err := provider.AuthHeader(context.Background())
				Expect(err).NotTo(HaveOccurred())
				Expect(header2).To(Equal("Bearer " + secondToken))
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
			// This test uses a plain-HTTP UAA server because AuthProvider uses
			// director_ca_cert only for its own HTTP client (not the UAA request
			// when the URL scheme is http). The meaningful TLS test is
			// "does not skip TLS verification" below, which uses httptest.NewTLSServer.
			It("builds the HTTP client successfully when director_ca_cert points to a valid cert file", func() {
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

			It("uses the director_ca_cert to trust a TLS UAA server when the cert matches", func() {
				tlsUAAServer := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					w.Header().Set("Content-Type", "application/json")
					fmt.Fprintf(w, `{"access_token":%q,"token_type":"bearer","expires_in":3600}`, firstToken)
				}))
				defer tlsUAAServer.Close()

				// Write the TLS server's certificate as the CA cert so the client trusts it.
				certPEM := pem.EncodeToMemory(&pem.Block{
					Type:  "CERTIFICATE",
					Bytes: tlsUAAServer.Certificate().Raw,
				})
				tmpFile, err := os.CreateTemp("", "uaa_ca_cert_*.pem")
				Expect(err).NotTo(HaveOccurred())
				defer os.Remove(tmpFile.Name())
				_, err = tmpFile.Write(certPEM)
				Expect(err).NotTo(HaveOccurred())
				Expect(tmpFile.Close()).To(Succeed())

				info := authprovider.InfoResponse{
					UserAuthentication: &authprovider.UserAuthentication{
						Type:    "uaa",
						Options: authprovider.UAAOptions{URL: tlsUAAServer.URL},
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
				Expect(header).To(Equal("Bearer " + firstToken))
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

		DescribeTable("reports configured CA read errors before requesting a token",
			func(useUAACA bool, permissionDenied bool) {
				certPath, err := os.MkdirTemp("", "unreadable_ca_*")
				Expect(err).NotTo(HaveOccurred())
				DeferCleanup(os.RemoveAll, certPath)
				if permissionDenied {
					if os.Geteuid() == 0 {
						Skip("root can read files without read permission")
					}
					certPath += "/ca.pem"
					Expect(os.WriteFile(certPath, generateTestCACertPEM(), 0o000)).To(Succeed())
				}
				cfg := config.DirectorConfig{DirectorCACert: certPath}
				if useUAACA {
					cfg.UAACACert = certPath
					cfg.DirectorCACert = ""
				}
				provider := authprovider.New(authprovider.InfoResponse{
					UserAuthentication: &authprovider.UserAuthentication{
						Type: "uaa", Options: authprovider.UAAOptions{URL: uaaServer.URL},
					},
				}, cfg, logger)
				header, err := provider.AuthHeader(context.Background())
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("cannot read CA certificate"))
				Expect(header).To(BeEmpty())
				Expect(tokenCounter).To(BeZero())
			},
			Entry("unreadable director CA", false, true),
			Entry("unreadable UAA CA", true, true),
			Entry("director CA path is a directory", false, false),
			Entry("UAA CA path is a directory", true, false),
		)

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
				Expect(header).To(Equal("Bearer " + firstToken))
			})

			// Mirrors Ruby AuthProvider#ca_file_path / UAAToken#initialize, where a
			// configured-but-missing path failed File.exist? and fell through to
			// OpenSSL::X509::Store#set_default_paths rather than raising.
			It("falls back to the system trust store when director_ca_cert points to a missing file", func() {
				cfg := makeCfg()
				cfg.DirectorCACert = "/nonexistent/director_ca_cert"
				provider := authprovider.New(makeInfo(), cfg, logger)

				header, err := provider.AuthHeader(context.Background())
				Expect(err).NotTo(HaveOccurred())
				Expect(header).To(Equal("Bearer " + firstToken))
			})

			It("falls back to the system trust store when both CA cert paths are missing files", func() {
				cfg := makeCfg()
				cfg.DirectorCACert = "/nonexistent/director_ca_cert"
				cfg.UAACACert = "/nonexistent/uaa_ca_cert"
				provider := authprovider.New(makeInfo(), cfg, logger)

				Expect(provider.CAFilePath()).To(BeEmpty())

				header, err := provider.AuthHeader(context.Background())
				Expect(err).NotTo(HaveOccurred())
				Expect(header).To(Equal("Bearer " + firstToken))
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
					tokenExpiresAt = time.Now().Add(30 * time.Second)
				})

				It("obtains a new token", func() {
					provider := authprovider.New(makeInfo(), makeCfg(), logger)

					header1, err := provider.AuthHeader(context.Background())
					Expect(err).NotTo(HaveOccurred())
					Expect(header1).To(Equal("Bearer " + firstToken))

					header2, err := provider.AuthHeader(context.Background())
					Expect(err).NotTo(HaveOccurred())
					Expect(header2).To(Equal("Bearer " + secondToken))
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
					fmt.Fprintf(w, `{"access_token":%q,"token_type":"bearer","expires_in":3600}`, firstToken)
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

	Context("when uaa_public_key is configured (JWT RS256 verification)", func() {
		// Mirrors Ruby UAAToken decode_options: when uaa_public_key is non-empty,
		// the fetched token's RS256 signature is verified against the public key.
		var (
			rsaPrivKey *rsa.PrivateKey
			pubKeyPEM  []byte
		)

		BeforeEach(func() {
			rsaPrivKey, pubKeyPEM = generateRSAKeyPair()
		})

		It("accepts a token whose RS256 signature matches uaa_public_key", func() {
			validJWT := createRS256JWT(rsaPrivKey, time.Now().Add(time.Hour))
			uaaServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Header().Set("Content-Type", "application/json")
				fmt.Fprintf(w, `{"access_token":%q,"token_type":"bearer","expires_in":3600}`, validJWT)
			}))
			defer uaaServer.Close()

			info := authprovider.InfoResponse{
				UserAuthentication: &authprovider.UserAuthentication{
					Type:    "uaa",
					Options: authprovider.UAAOptions{URL: uaaServer.URL},
				},
			}
			cfg := config.DirectorConfig{
				ClientID:     "fake-client",
				ClientSecret: "fake-secret",
				UAAPublicKey: string(pubKeyPEM),
			}
			provider := authprovider.New(info, cfg, logger)

			header, err := provider.AuthHeader(context.Background())
			Expect(err).NotTo(HaveOccurred())
			Expect(header).To(Equal("Bearer " + validJWT))
		})

		// Ruby's OpenSSL::PKey::RSA.new accepts both PKIX ("PUBLIC KEY") and
		// PKCS#1 ("RSA PUBLIC KEY") PEM encodings for uaa_public_key.
		It("accepts a PKCS#1 (BEGIN RSA PUBLIC KEY) uaa_public_key", func() {
			pkcs1PEM := pem.EncodeToMemory(&pem.Block{
				Type:  "RSA PUBLIC KEY",
				Bytes: x509.MarshalPKCS1PublicKey(&rsaPrivKey.PublicKey),
			})
			validJWT := createRS256JWT(rsaPrivKey, time.Now().Add(time.Hour))
			uaaServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Header().Set("Content-Type", "application/json")
				fmt.Fprintf(w, `{"access_token":%q,"token_type":"bearer","expires_in":3600}`, validJWT)
			}))
			defer uaaServer.Close()

			info := authprovider.InfoResponse{
				UserAuthentication: &authprovider.UserAuthentication{
					Type:    "uaa",
					Options: authprovider.UAAOptions{URL: uaaServer.URL},
				},
			}
			cfg := config.DirectorConfig{
				ClientID:     "fake-client",
				ClientSecret: "fake-secret",
				UAAPublicKey: string(pkcs1PEM),
			}
			provider := authprovider.New(info, cfg, logger)

			header, err := provider.AuthHeader(context.Background())
			Expect(err).NotTo(HaveOccurred())
			Expect(header).To(Equal("Bearer " + validJWT))
		})

		It("accepts a token whose RS384 signature matches uaa_public_key", func() {
			validJWT := createRSAJWT(rsaPrivKey, time.Now().Add(time.Hour), "RS384", crypto.SHA384)
			uaaServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Header().Set("Content-Type", "application/json")
				fmt.Fprintf(w, `{"access_token":%q,"token_type":"bearer","expires_in":3600}`, validJWT)
			}))
			defer uaaServer.Close()

			info := authprovider.InfoResponse{
				UserAuthentication: &authprovider.UserAuthentication{
					Type:    "uaa",
					Options: authprovider.UAAOptions{URL: uaaServer.URL},
				},
			}
			cfg := config.DirectorConfig{
				ClientID:     "fake-client",
				ClientSecret: "fake-secret",
				UAAPublicKey: string(pubKeyPEM),
			}
			provider := authprovider.New(info, cfg, logger)

			header, err := provider.AuthHeader(context.Background())
			Expect(err).NotTo(HaveOccurred())
			Expect(header).To(Equal("Bearer " + validJWT))
		})

		It("accepts a token whose RS512 signature matches uaa_public_key", func() {
			validJWT := createRSAJWT(rsaPrivKey, time.Now().Add(time.Hour), "RS512", crypto.SHA512)
			uaaServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Header().Set("Content-Type", "application/json")
				fmt.Fprintf(w, `{"access_token":%q,"token_type":"bearer","expires_in":3600}`, validJWT)
			}))
			defer uaaServer.Close()

			info := authprovider.InfoResponse{
				UserAuthentication: &authprovider.UserAuthentication{
					Type:    "uaa",
					Options: authprovider.UAAOptions{URL: uaaServer.URL},
				},
			}
			cfg := config.DirectorConfig{
				ClientID:     "fake-client",
				ClientSecret: "fake-secret",
				UAAPublicKey: string(pubKeyPEM),
			}
			provider := authprovider.New(info, cfg, logger)

			header, err := provider.AuthHeader(context.Background())
			Expect(err).NotTo(HaveOccurred())
			Expect(header).To(Equal("Bearer " + validJWT))
		})

		It("rejects a token signed with an unsupported algorithm", func() {
			header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"HS256","typ":"JWT"}`))
			claimsJSON, _ := json.Marshal(map[string]interface{}{
				"sub": "test-client",
				"exp": time.Now().Add(time.Hour).Unix(),
			})
			payload := base64.RawURLEncoding.EncodeToString(claimsJSON)
			unsupportedJWT := header + "." + payload + "." + base64.RawURLEncoding.EncodeToString([]byte("sig"))

			uaaServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Header().Set("Content-Type", "application/json")
				fmt.Fprintf(w, `{"access_token":%q,"token_type":"bearer","expires_in":3600}`, unsupportedJWT)
			}))
			defer uaaServer.Close()

			info := authprovider.InfoResponse{
				UserAuthentication: &authprovider.UserAuthentication{
					Type:    "uaa",
					Options: authprovider.UAAOptions{URL: uaaServer.URL},
				},
			}
			cfg := config.DirectorConfig{
				ClientID:     "fake-client",
				ClientSecret: "fake-secret",
				UAAPublicKey: string(pubKeyPEM),
			}
			provider := authprovider.New(info, cfg, logger)

			_, err := provider.AuthHeader(context.Background())
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("unsupported JWT algorithm"))
		})

		It("rejects a token signed with a different RSA key", func() {
			otherKey, _ := generateRSAKeyPair()
			wrongJWT := createRS256JWT(otherKey, time.Now().Add(time.Hour))

			uaaServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Header().Set("Content-Type", "application/json")
				fmt.Fprintf(w, `{"access_token":%q,"token_type":"bearer","expires_in":3600}`, wrongJWT)
			}))
			defer uaaServer.Close()

			info := authprovider.InfoResponse{
				UserAuthentication: &authprovider.UserAuthentication{
					Type:    "uaa",
					Options: authprovider.UAAOptions{URL: uaaServer.URL},
				},
			}
			cfg := config.DirectorConfig{
				ClientID:     "fake-client",
				ClientSecret: "fake-secret",
				UAAPublicKey: string(pubKeyPEM),
			}
			provider := authprovider.New(info, cfg, logger)

			_, err := provider.AuthHeader(context.Background())
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("UAA JWT signature verification failed"))
		})

		It("skips signature verification when uaa_public_key is empty", func() {
			otherKey, _ := generateRSAKeyPair()
			validJWT := createRS256JWT(otherKey, time.Now().Add(time.Hour))
			uaaServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Header().Set("Content-Type", "application/json")
				fmt.Fprintf(w, `{"access_token":%q,"token_type":"bearer","expires_in":3600}`, validJWT)
			}))
			defer uaaServer.Close()

			info := authprovider.InfoResponse{
				UserAuthentication: &authprovider.UserAuthentication{
					Type:    "uaa",
					Options: authprovider.UAAOptions{URL: uaaServer.URL},
				},
			}
			cfg := config.DirectorConfig{
				ClientID:     "fake-client",
				ClientSecret: "fake-secret",
				UAAPublicKey: "",
			}
			provider := authprovider.New(info, cfg, logger)

			header, err := provider.AuthHeader(context.Background())
			Expect(err).NotTo(HaveOccurred())
			Expect(header).To(Equal("Bearer " + validJWT))
		})
	})

	Context("JWT decoding and expiration", func() {
		newProvider := func(token string, expiresIn int, publicKey string) (*authprovider.AuthProvider, *atomic.Int32) {
			requests := &atomic.Int32{}
			uaaServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				requests.Add(1)
				w.Header().Set("Content-Type", "application/json")
				response := map[string]interface{}{"access_token": token, "token_type": "bearer"}
				if expiresIn != 0 {
					response["expires_in"] = expiresIn
				}
				json.NewEncoder(w).Encode(response)
			}))
			DeferCleanup(uaaServer.Close)
			info := authprovider.InfoResponse{
				UserAuthentication: &authprovider.UserAuthentication{
					Type:    "uaa",
					Options: authprovider.UAAOptions{URL: uaaServer.URL},
				},
			}
			return authprovider.New(info, config.DirectorConfig{
				ClientID:     "fake-client",
				ClientSecret: "fake-secret",
				UAAPublicKey: publicKey,
			}, logger), requests
		}

		DescribeTable("uses JWT exp to decide when to refresh",
			func(lifetime time.Duration, expiresIn int, verify bool, expectedRequests int32) {
				key, publicKey := generateRSAKeyPair()
				token := createRS256JWT(key, time.Now().Add(lifetime))
				if !verify {
					publicKey = nil
				}
				provider, requests := newProvider(token, expiresIn, string(publicKey))

				for range 2 {
					header, err := provider.AuthHeader(context.Background())
					Expect(err).NotTo(HaveOccurred())
					Expect(header).To(Equal("Bearer " + token))
				}
				Expect(requests.Load()).To(Equal(expectedRequests))
			},
			Entry("refreshes an expiring JWT despite a longer expires_in, without signature verification", 30*time.Second, 3600, false, int32(2)),
			Entry("refreshes an expiring JWT despite a longer expires_in, with signature verification", 30*time.Second, 3600, true, int32(2)),
			Entry("caches a valid JWT despite a shorter expires_in, without signature verification", time.Hour, 30, false, int32(1)),
			Entry("caches a valid JWT despite a shorter expires_in, with signature verification", time.Hour, 30, true, int32(1)),
			Entry("caches a valid JWT without expires_in or signature verification", time.Hour, 0, false, int32(1)),
			Entry("caches a valid JWT without expires_in and with signature verification", time.Hour, 0, true, int32(1)),
			Entry("refreshes an expired JWT on subsequent requests", -time.Minute, 3600, false, int32(2)),
		)

		encodedHeader := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"RS256"}`))
		encodedClaims := base64.RawURLEncoding.EncodeToString([]byte(`{"exp":4102444800}`))
		DescribeTable("rejects malformed JWTs without a configured public key",
			func(token string) {
				provider, requests := newProvider(token, 3600, "")
				for range 2 {
					header, err := provider.AuthHeader(context.Background())
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("failed to decode token from UAA"))
					Expect(header).To(BeEmpty())
				}
				Expect(requests.Load()).To(Equal(int32(2)))
			},
			Entry("opaque token", "opaque-token"),
			Entry("extra segment", encodedHeader+"."+encodedClaims+".signature.extra"),
			Entry("invalid header encoding", "!invalid."+encodedClaims+".signature"),
			Entry("invalid header JSON", "e30x."+encodedClaims+".signature"),
			Entry("null header", "bnVsbA."+encodedClaims+".signature"),
			Entry("invalid payload encoding", encodedHeader+".!invalid.signature"),
			Entry("invalid payload JSON", encodedHeader+".e30x.signature"),
			Entry("missing expiration", encodedHeader+".e30.signature"),
			Entry("null expiration", encodedHeader+"."+base64.RawURLEncoding.EncodeToString([]byte(`{"exp":null}`))+".signature"),
			Entry("nonnumeric expiration", encodedHeader+"."+base64.RawURLEncoding.EncodeToString([]byte(`{"exp":"invalid"}`))+".signature"),
		)

		DescribeTable("rejects malformed claims even when the signature is valid",
			func(payload string) {
				key, publicKey := generateRSAKeyPair()
				token := signRSAJWT(key, []byte(payload), "RS256", crypto.SHA256)
				provider, requests := newProvider(token, 3600, string(publicKey))
				for range 2 {
					header, err := provider.AuthHeader(context.Background())
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("failed to decode token from UAA"))
					Expect(header).To(BeEmpty())
				}
				Expect(requests.Load()).To(Equal(int32(2)))
			},
			Entry("invalid JSON", "not json"),
			Entry("missing expiration", `{}`),
		)
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
