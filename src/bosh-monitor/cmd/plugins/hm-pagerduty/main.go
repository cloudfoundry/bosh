package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
)

// apiURI is a var so tests can override it with an httptest.Server address.
var apiURI = "https://events.pagerduty.com/generic/2010-04-15/create_event.json"

type pagerdutyOptions struct {
	ServiceKey string `json:"service_key"`
	HTTPProxy  string `json:"http_proxy"`
	// CACert is an optional file path for a PEM-encoded CA certificate. When
	// set, the HTTPS client uses this certificate to verify the PagerDuty
	// endpoint instead of the system trust store. Mirrors the director_ca_cert
	// option used by the email and resurrector plugins.
	CACert string `json:"ca_cert"`
}

func main() { pluginlib.Run(runPagerduty) }

func runPagerduty(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
	var opts pagerdutyOptions
	if err := json.Unmarshal(rawOpts, &opts); err != nil {
		return fmt.Errorf("invalid options: %w", err)
	}
	if opts.ServiceKey == "" {
		return fmt.Errorf("service_key required")
	}

	cmds <- pluginlib.LogCommand("info", "Pagerduty delivery agent is running...")

	tlsCfg := &tls.Config{}
	if opts.CACert != "" {
		if pem, err := os.ReadFile(opts.CACert); err == nil {
			pool := x509.NewCertPool()
			if pool.AppendCertsFromPEM(pem) {
				tlsCfg.RootCAs = pool
			} else {
				cmds <- pluginlib.LogCommand("warn", fmt.Sprintf("ca_cert at %q contained no usable PEM blocks; falling back to system trust store", opts.CACert))
			}
		} else {
			cmds <- pluginlib.LogCommand("warn", fmt.Sprintf("Failed to read ca_cert from %q: %v; falling back to system trust store", opts.CACert, err))
		}
	}
	transport := &http.Transport{
		TLSClientConfig: tlsCfg,
	}
	if opts.HTTPProxy != "" {
		if proxyURL, err := url.Parse(opts.HTTPProxy); err == nil {
			transport.Proxy = http.ProxyURL(proxyURL)
		} else {
			cmds <- pluginlib.LogCommand("warn", fmt.Sprintf("Invalid http_proxy URL: %v", err))
		}
	}
	client := &http.Client{
		Timeout:   30 * time.Second,
		Transport: transport,
	}

	for {
		select {
		case <-ctx.Done():
			return nil
		case env, ok := <-events:
			if !ok {
				return nil
			}
			if env.Event == nil {
				continue
			}

			event := env.Event
			shortDesc := eventShortDescription(event)

			payload, _ := json.Marshal(map[string]interface{}{
				"service_key":  opts.ServiceKey,
				"event_type":   "trigger",
				"incident_key": event.ID,
				"description":  shortDesc,
				"details":      eventToHash(event),
			})

			go func(c context.Context, pl []byte) {
				resp, err := client.Post(apiURI, "application/json", bytes.NewReader(pl))
				if err != nil {
					select {
					case cmds <- pluginlib.LogCommand("error", fmt.Sprintf("Error sending pagerduty event: %v", err)):
					case <-c.Done():
					}
					return
				}
				_ = resp.Body.Close()
			}(ctx, payload)
		}
	}
}

func eventShortDescription(e *pluginlib.EventData) string {
	switch e.Kind {
	case "alert":
		return fmt.Sprintf("Severity %d: %s %s", e.Severity, e.Source, e.Title)
	case "heartbeat":
		return fmt.Sprintf("Heartbeat from %s/%s (agent_id=%s)", e.Job, e.InstanceID, e.AgentID)
	default:
		return e.ID
	}
}

func eventToHash(e *pluginlib.EventData) map[string]interface{} {
	result := map[string]interface{}{
		"kind": e.Kind,
		"id":   e.ID,
	}
	if e.Kind == "alert" {
		result["severity"] = e.Severity
		result["title"] = e.Title
		result["summary"] = e.Summary
		result["source"] = e.Source
		result["deployment"] = e.Deployment
		result["created_at"] = e.CreatedAt
	} else {
		result["timestamp"] = e.Timestamp
		result["deployment"] = e.Deployment
		result["agent_id"] = e.AgentID
		result["job"] = e.Job
		result["instance_id"] = e.InstanceID
	}
	return result
}
