package nats

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"log/slog"
	"os"
	"time"

	"github.com/nats-io/nats.go"
)

type MessageHandler func(kind, subject string, payload string)

type Client struct {
	conn    *nats.Conn
	logger  *slog.Logger
	handler MessageHandler
}

type Config struct {
	Endpoint             string
	ServerCAPath         string
	ClientCertificatePath string
	ClientPrivateKeyPath string
	ConnectionWaitTimeout int
}

const (
	DefaultConnectionWaitTimeout = 60
	DefaultRetryInterval         = 1
)

func NewClient(logger *slog.Logger) *Client {
	return &Client{logger: logger}
}

func (c *Client) Connect(cfg Config) error {
	tlsConfig, err := buildTLSConfig(cfg)
	if err != nil {
		return fmt.Errorf("failed to build TLS config: %w", err)
	}

	timeout := cfg.ConnectionWaitTimeout
	if timeout == 0 {
		timeout = DefaultConnectionWaitTimeout
	}
	maxAttempts := timeout / DefaultRetryInterval
	if maxAttempts < 1 {
		maxAttempts = 1
	}

	var lastErr error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		opts := []nats.Option{
			nats.Secure(tlsConfig),
			nats.MaxReconnects(4),
			nats.ReconnectWait(2 * time.Second),
			nats.DontRandomize(),
			nats.ErrorHandler(func(_ *nats.Conn, _ *nats.Subscription, err error) {
				c.logger.Error("NATS client error", "error", err)
			}),
		}

		conn, err := nats.Connect(cfg.Endpoint, opts...)
		if err != nil {
			lastErr = err
			if attempt < maxAttempts {
				c.logger.Info("Waiting for NATS to become available",
					"attempt", attempt+1, "max_attempts", maxAttempts, "error", err)
				time.Sleep(time.Duration(DefaultRetryInterval) * time.Second)
			}
			continue
		}

		c.conn = conn
		c.logger.Info("Connected to NATS", "endpoint", cfg.Endpoint)
		return nil
	}

	return fmt.Errorf("failed to connect to NATS after %d attempts: %w", maxAttempts, lastErr)
}

func (c *Client) Subscribe(handler MessageHandler) error {
	c.handler = handler

	subjects := map[string]string{
		"hm.agent.heartbeat.*": "heartbeat",
		"hm.agent.alert.*":    "alert",
		"hm.agent.shutdown.*": "shutdown",
	}

	for subject, kind := range subjects {
		k := kind
		_, err := c.conn.Subscribe(subject, func(msg *nats.Msg) {
			c.handler(k, msg.Subject, string(msg.Data))
		})
		if err != nil {
			return fmt.Errorf("failed to subscribe to %s: %w", subject, err)
		}
	}

	return nil
}

func (c *Client) SubscribeDirectorAlerts(handler func(payload string)) error {
	_, err := c.conn.Subscribe("hm.director.alert", func(msg *nats.Msg) {
		handler(string(msg.Data))
	})
	return err
}

func (c *Client) Close() {
	if c.conn != nil {
		c.conn.Close()
	}
}

func buildTLSConfig(cfg Config) (*tls.Config, error) {
	cert, err := tls.LoadX509KeyPair(cfg.ClientCertificatePath, cfg.ClientPrivateKeyPath)
	if err != nil {
		return nil, fmt.Errorf("failed to load client certificate: %w", err)
	}

	caCert, err := os.ReadFile(cfg.ServerCAPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read CA certificate: %w", err)
	}

	caCertPool := x509.NewCertPool()
	if !caCertPool.AppendCertsFromPEM(caCert) {
		return nil, fmt.Errorf("failed to parse CA certificate")
	}

	return &tls.Config{
		Certificates: []tls.Certificate{cert},
		RootCAs:      caCertPool,
		MinVersion:   tls.VersionTLS12,
	}, nil
}
