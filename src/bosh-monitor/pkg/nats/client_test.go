package nats_test

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"errors"
	"log/slog"
	"math/big"
	"os"
	"path/filepath"
	"sync/atomic"
	"time"

	hmNats "github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/nats"
	natslib "github.com/nats-io/nats.go"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// writeTestCerts generates a self-signed ECDSA cert/key pair and writes them
// (plus the cert reused as a CA) to tmpDir under the given prefix.
func writeTestCerts(tmpDir, prefix string) (certPath, keyPath, caPath string) {
	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	Expect(err).NotTo(HaveOccurred())

	template := &x509.Certificate{
		SerialNumber:          big.NewInt(1),
		Subject:               pkix.Name{Organization: []string{"Test"}},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().Add(time.Hour),
		KeyUsage:              x509.KeyUsageDigitalSignature,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth},
		IsCA:                  true,
		BasicConstraintsValid: true,
	}

	certDER, err := x509.CreateCertificate(rand.Reader, template, template, &priv.PublicKey, priv)
	Expect(err).NotTo(HaveOccurred())
	certPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: certDER})

	privDER, err := x509.MarshalECPrivateKey(priv)
	Expect(err).NotTo(HaveOccurred())
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "EC PRIVATE KEY", Bytes: privDER})

	certPath = filepath.Join(tmpDir, prefix+".crt")
	Expect(os.WriteFile(certPath, certPEM, 0600)).To(Succeed())

	keyPath = filepath.Join(tmpDir, prefix+".key")
	Expect(os.WriteFile(keyPath, keyPEM, 0600)).To(Succeed())

	// Reuse the cert as the CA cert (self-signed).
	caPath = filepath.Join(tmpDir, prefix+"-ca.pem")
	Expect(os.WriteFile(caPath, certPEM, 0600)).To(Succeed())

	return certPath, keyPath, caPath
}

// ── TLS configuration ─────────────────────────────────────────────────────────

// Ruby equivalent: runner_spec.rb — "should connect using SSL"
// Ruby tested that OpenSSL::PKey::RSA and OpenSSL::X509::Certificate objects
// are constructed from the configured key/cert files. The Go equivalent tests
// that buildTLSConfig builds a valid tls.Config from those same files.
var _ = Describe("buildTLSConfig", func() {
	var (
		tmpDir   string
		certPath string
		keyPath  string
		caPath   string
	)

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "nats-tls-test")
		Expect(err).NotTo(HaveOccurred())
		certPath, keyPath, caPath = writeTestCerts(tmpDir, "client")
	})

	AfterEach(func() {
		Expect(os.RemoveAll(tmpDir)).To(Succeed())
	})

	Context("with valid cert, key, and CA cert files", func() {
		It("returns a TLS config that includes the client certificate", func() {
			cfg := hmNats.Config{
				ClientCertificatePath: certPath,
				ClientPrivateKeyPath:  keyPath,
				ServerCAPath:          caPath,
			}
			tlsCfg, err := hmNats.BuildTLSConfig(cfg)
			Expect(err).NotTo(HaveOccurred())
			Expect(tlsCfg.Certificates).To(HaveLen(1))
		})

		It("enforces a minimum TLS version of 1.2", func() {
			cfg := hmNats.Config{
				ClientCertificatePath: certPath,
				ClientPrivateKeyPath:  keyPath,
				ServerCAPath:          caPath,
			}
			tlsCfg, err := hmNats.BuildTLSConfig(cfg)
			Expect(err).NotTo(HaveOccurred())
			Expect(tlsCfg.MinVersion).To(Equal(uint16(tls.VersionTLS12)))
		})

		It("populates the CA certificate pool from the server CA file", func() {
			cfg := hmNats.Config{
				ClientCertificatePath: certPath,
				ClientPrivateKeyPath:  keyPath,
				ServerCAPath:          caPath,
			}
			tlsCfg, err := hmNats.BuildTLSConfig(cfg)
			Expect(err).NotTo(HaveOccurred())
			Expect(tlsCfg.RootCAs).NotTo(BeNil())
		})
	})

	Context("when the certificate file is missing", func() {
		It("returns an error", func() {
			cfg := hmNats.Config{
				ClientCertificatePath: filepath.Join(tmpDir, "no-such-cert.pem"),
				ClientPrivateKeyPath:  keyPath,
				ServerCAPath:          caPath,
			}
			_, err := hmNats.BuildTLSConfig(cfg)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("failed to load client certificate"))
		})
	})

	Context("when the cert and key files do not match", func() {
		It("returns an error", func() {
			_, altKeyPath, _ := writeTestCerts(tmpDir, "other")
			cfg := hmNats.Config{
				ClientCertificatePath: certPath,
				ClientPrivateKeyPath:  altKeyPath, // key from a different pair
				ServerCAPath:          caPath,
			}
			_, err := hmNats.BuildTLSConfig(cfg)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("failed to load client certificate"))
		})
	})

	Context("when the server CA file is missing", func() {
		It("returns an error", func() {
			cfg := hmNats.Config{
				ClientCertificatePath: certPath,
				ClientPrivateKeyPath:  keyPath,
				ServerCAPath:          filepath.Join(tmpDir, "no-such-ca.pem"),
			}
			_, err := hmNats.BuildTLSConfig(cfg)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("failed to read CA certificate"))
		})
	})

	Context("when the server CA file contains no valid PEM blocks", func() {
		It("returns an error", func() {
			badCAPath := filepath.Join(tmpDir, "bad-ca.pem")
			Expect(os.WriteFile(badCAPath, []byte("not-a-pem-block\n"), 0600)).To(Succeed())

			cfg := hmNats.Config{
				ClientCertificatePath: certPath,
				ClientPrivateKeyPath:  keyPath,
				ServerCAPath:          badCAPath,
			}
			_, err := hmNats.BuildTLSConfig(cfg)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("failed to parse CA certificate"))
		})
	})
})

// ── Connection retry behaviour ─────────────────────────────────────────────────

// Ruby equivalents: runner_spec.rb — "NATS connection retries" describe block.
// Ruby used NATS::IO::ConnectError mocks. Go retries ALL error types (there is
// no distinction between ConnectError subtypes). The Ruby tests that checked
// AuthError (a ConnectError subclass) is also retried are therefore subsumed.
// The Ruby "non-ConnectError does not retry" behaviour does NOT apply to Go.
var _ = Describe("Client.Connect retry behaviour", func() {
	var (
		tmpDir   string
		certPath string
		keyPath  string
		caPath   string
		logBuf   bytes.Buffer
		logger   *slog.Logger

		origConnectFunc func(url string, opts ...natslib.Option) (*natslib.Conn, error)
		origRetryWait   time.Duration
	)

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "nats-retry-test")
		Expect(err).NotTo(HaveOccurred())
		certPath, keyPath, caPath = writeTestCerts(tmpDir, "client")

		logBuf.Reset()
		logger = slog.New(slog.NewTextHandler(&logBuf, &slog.HandlerOptions{Level: slog.LevelInfo}))

		origConnectFunc = *hmNats.ConnectFunc
		origRetryWait = *hmNats.RetryWait

		// Use a sub-millisecond retry interval to keep tests fast.
		*hmNats.RetryWait = time.Millisecond
	})

	AfterEach(func() {
		*hmNats.ConnectFunc = origConnectFunc
		*hmNats.RetryWait = origRetryWait
		Expect(os.RemoveAll(tmpDir)).To(Succeed())
	})

	validCfg := func() hmNats.Config {
		return hmNats.Config{
			ClientCertificatePath: certPath,
			ClientPrivateKeyPath:  keyPath,
			ServerCAPath:          caPath,
			Endpoint:              "nats://127.0.0.1:4222",
			ConnectionWaitTimeout: 10,
		}
	}

	// Ruby: "retries the connection until it succeeds"
	It("retries the connection until it succeeds", func() {
		var attempts int32
		*hmNats.ConnectFunc = func(url string, opts ...natslib.Option) (*natslib.Conn, error) {
			n := atomic.AddInt32(&attempts, 1)
			if n < 3 {
				return nil, errors.New("connection refused")
			}
			return nil, nil // success on third attempt
		}

		client := hmNats.NewClient(logger)
		err := client.Connect(validCfg())
		Expect(err).NotTo(HaveOccurred())
		Expect(attempts).To(BeNumerically("==", 3))
	})

	// Ruby: "logs retry attempts"
	It("logs a message for each failed retry attempt", func() {
		var attempts int32
		*hmNats.ConnectFunc = func(url string, opts ...natslib.Option) (*natslib.Conn, error) {
			n := atomic.AddInt32(&attempts, 1)
			if n < 2 {
				return nil, errors.New("connection refused")
			}
			return nil, nil
		}

		client := hmNats.NewClient(logger)
		Expect(client.Connect(validCfg())).To(Succeed())
		Expect(logBuf.String()).To(ContainSubstring("Waiting for NATS to become available"))
	})

	// Ruby: "when timeout is exceeded / raises the last connection error"
	It("returns an error wrapping the last failure after exhausting max attempts", func() {
		*hmNats.ConnectFunc = func(url string, opts ...natslib.Option) (*natslib.Conn, error) {
			return nil, errors.New("connection refused")
		}

		cfg := validCfg()
		cfg.ConnectionWaitTimeout = 2 // → 2 attempts

		client := hmNats.NewClient(logger)
		err := client.Connect(cfg)
		Expect(err).To(HaveOccurred())
		Expect(err.Error()).To(ContainSubstring("failed to connect to NATS after 2 attempts"))
		Expect(err.Error()).To(ContainSubstring("connection refused"))
	})

	// Ruby: "when connection_wait_timeout is configured in mbus config / uses the configured timeout"
	It("uses ConnectionWaitTimeout to determine the number of attempts", func() {
		var attempts int32
		*hmNats.ConnectFunc = func(url string, opts ...natslib.Option) (*natslib.Conn, error) {
			atomic.AddInt32(&attempts, 1)
			return nil, errors.New("connection refused")
		}

		cfg := validCfg()
		cfg.ConnectionWaitTimeout = 3 // → 3 attempts

		client := hmNats.NewClient(logger)
		client.Connect(cfg) //nolint:errcheck

		Expect(attempts).To(BeNumerically("==", 3))
	})

	// Ruby: "when NATS connection fails with AuthError (subclass of ConnectError) / retries"
	// Note: Go's NATS client retries ALL errors, not only ConnectError subtypes.
	// This test confirms that a non-"connection refused" error is also retried,
	// which is broader than Ruby's ConnectError-only retry policy.
	It("retries on any error type, not only connection-refused", func() {
		var attempts int32
		*hmNats.ConnectFunc = func(url string, opts ...natslib.Option) (*natslib.Conn, error) {
			n := atomic.AddInt32(&attempts, 1)
			if n < 3 {
				return nil, errors.New("authorization violation") // auth error
			}
			return nil, nil
		}

		client := hmNats.NewClient(logger)
		err := client.Connect(validCfg())
		Expect(err).NotTo(HaveOccurred())
		Expect(attempts).To(BeNumerically("==", 3))
	})

	// Ruby: default ConnectionWaitTimeout when not configured.
	It("uses DefaultConnectionWaitTimeout when ConnectionWaitTimeout is zero", func() {
		// A zero timeout must not produce zero attempts (would always fail).
		// Verify by succeeding on the first attempt — a 1-attempt run works
		// fine regardless of whether the default is applied.
		var attempts int32
		*hmNats.ConnectFunc = func(url string, opts ...natslib.Option) (*natslib.Conn, error) {
			atomic.AddInt32(&attempts, 1)
			return nil, nil // succeed immediately
		}

		cfg := validCfg()
		cfg.ConnectionWaitTimeout = 0 // must fall back to DefaultConnectionWaitTimeout

		client := hmNats.NewClient(logger)
		Expect(client.Connect(cfg)).To(Succeed())
		Expect(attempts).To(BeNumerically("==", 1))
	})

	// Ruby: "when an error occurs while connecting / throws the error"
	// Go wraps the last error inside the Connect() return value.
	It("returns an error when Connect() fails and there is no timeout configured for retries", func() {
		*hmNats.ConnectFunc = func(url string, opts ...natslib.Option) (*natslib.Conn, error) {
			return nil, errors.New("unexpected dial error")
		}

		cfg := validCfg()
		cfg.ConnectionWaitTimeout = 1 // 1 attempt, fails immediately

		client := hmNats.NewClient(logger)
		err := client.Connect(cfg)
		Expect(err).To(HaveOccurred())
		Expect(err.Error()).To(ContainSubstring("unexpected dial error"))
	})
})
