package main

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"net/smtp"
	"strings"
	"sync"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
)

type emailOptions struct {
	Recipients []string               `json:"recipients"`
	SMTP       map[string]interface{} `json:"smtp"`
	Interval   float64                `json:"interval"`
}

func main() { pluginlib.Run(runEmail) }

func runEmail(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
	var opts emailOptions
	if err := json.Unmarshal(rawOpts, &opts); err != nil {
		return fmt.Errorf("invalid options: %w", err)
	}

	if len(opts.Recipients) == 0 {
		return fmt.Errorf("recipients required")
	}
	if opts.SMTP == nil {
		return fmt.Errorf("smtp options required")
	}

	interval := 10.0
	if opts.Interval > 0 {
		interval = opts.Interval
	}

	var mu sync.Mutex
	queues := make(map[string][]string)

	go func() {
		ticker := time.NewTicker(time.Duration(interval * float64(time.Second)))
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				mu.Lock()
				for kind, queue := range queues {
					if len(queue) == 0 {
						continue
					}
					subject := fmt.Sprintf("%d %s(s) from BOSH Health Monitor", len(queue), kind)
					body := strings.Join(queue, "\n")
					queues[kind] = nil

					go func(subj, bod string) {
						if err := sendEmail(opts, subj, bod); err != nil {
							pluginlib.SendCommand(ctx, cmds, pluginlib.LogCommand("error", fmt.Sprintf("Failed to send email: %v", err)))
						} else {
							pluginlib.SendCommand(ctx, cmds, pluginlib.LogCommand("debug", "Email sent"))
						}
					}(subject, body)
				}
				mu.Unlock()
			}
		}
	}()

	cmds <- pluginlib.LogCommand("info", "Email plugin is running...")

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
			text := eventToPlainText(env.Event)
			mu.Lock()
			queues[env.Event.Kind] = append(queues[env.Event.Kind], text)
			mu.Unlock()
		}
	}
}

func eventToPlainText(e *pluginlib.EventData) string {
	switch e.Kind {
	case "alert":
		result := ""
		if e.Source != "" {
			result += e.Source + "\n"
		}
		if e.Title != "" {
			result += e.Title + "\n"
		}
		result += fmt.Sprintf("Severity: %d\n", e.Severity)
		if e.Summary != "" {
			result += fmt.Sprintf("Summary: %s\n", e.Summary)
		}
		return result
	default:
		return fmt.Sprintf("Heartbeat from %s/%s", e.Job, e.InstanceID)
	}
}

// sendEmail mirrors the Ruby email plugin, which connects in plaintext and
// upgrades via STARTTLS when `tls` is set (Net::SMTP.new(host, port,
// starttls: :always|false)) — NOT implicit TLS on connect. Using implicit TLS
// would fail against the common STARTTLS submission port (587).
func sendEmail(opts emailOptions, subject, body string) error {
	host, _ := opts.SMTP["host"].(string)
	port := fmt.Sprintf("%v", opts.SMTP["port"])
	from, _ := opts.SMTP["from"].(string)
	useTLS, _ := opts.SMTP["tls"].(bool)

	headers := fmt.Sprintf("From: %s\r\nTo: %s\r\nSubject: %s\r\nDate: %s\r\nContent-Type: text/plain; charset=\"iso-8859-1\"\r\n\r\n",
		from, strings.Join(opts.Recipients, ", "), subject, time.Now().Format(time.RFC1123Z))
	msg := headers + body

	c, err := smtp.Dial(host + ":" + port)
	if err != nil {
		return err
	}
	defer func() { _ = c.Close() }()

	if useTLS {
		if err := c.StartTLS(&tls.Config{ServerName: host}); err != nil {
			return err
		}
	}

	if auth := smtpAuth(opts, host); auth != nil {
		if err := c.Auth(auth); err != nil {
			return err
		}
	}

	if err := c.Mail(from); err != nil {
		return err
	}
	for _, r := range opts.Recipients {
		if err := c.Rcpt(r); err != nil {
			return err
		}
	}
	w, err := c.Data()
	if err != nil {
		return err
	}
	if _, err := w.Write([]byte(msg)); err != nil {
		return err
	}
	if err := w.Close(); err != nil {
		return err
	}
	return c.Quit()
}

// smtpAuth maps the Ruby `auth` option (a Net::SMTP auth symbol) to a Go
// smtp.Auth. Ruby supports :plain, :login and :cram_md5; the Go stdlib offers
// PLAIN and CRAM-MD5 (LOGIN is not available in net/smtp).
func smtpAuth(opts emailOptions, host string) smtp.Auth {
	authType, _ := opts.SMTP["auth"].(string)
	user, _ := opts.SMTP["user"].(string)
	password, _ := opts.SMTP["password"].(string)
	if authType == "" || user == "" {
		return nil
	}
	switch strings.ToLower(authType) {
	case "cram_md5", "cram-md5":
		return smtp.CRAMMD5Auth(user, password)
	default:
		return smtp.PlainAuth("", user, password, host)
	}
}
