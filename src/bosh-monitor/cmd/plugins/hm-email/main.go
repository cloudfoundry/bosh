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

func main() {
	pluginlib.Run(func(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
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
								cmds <- pluginlib.LogCommand("error", fmt.Sprintf("Failed to send email: %v", err))
							} else {
								cmds <- pluginlib.LogCommand("debug", "Email sent")
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
	})
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

func sendEmail(opts emailOptions, subject, body string) error {
	host, _ := opts.SMTP["host"].(string)
	port := fmt.Sprintf("%v", opts.SMTP["port"])
	from, _ := opts.SMTP["from"].(string)
	useTLS, _ := opts.SMTP["tls"].(bool)

	headers := fmt.Sprintf("From: %s\r\nTo: %s\r\nSubject: %s\r\nDate: %s\r\nContent-Type: text/plain; charset=\"iso-8859-1\"\r\n\r\n",
		from, strings.Join(opts.Recipients, ", "), subject, time.Now().Format(time.RFC1123Z))
	msg := headers + body

	addr := host + ":" + port

	if useTLS {
		conn, err := tls.Dial("tcp", addr, &tls.Config{ServerName: host})
		if err != nil {
			return err
		}
		c, err := smtp.NewClient(conn, host)
		if err != nil {
			return err
		}
		defer c.Close()

		if auth := smtpAuth(opts); auth != nil {
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
		w.Write([]byte(msg))
		return w.Close()
	}

	var auth smtp.Auth
	if a := smtpAuth(opts); a != nil {
		auth = a
	}
	return smtp.SendMail(addr, auth, from, opts.Recipients, []byte(msg))
}

func smtpAuth(opts emailOptions) smtp.Auth {
	authType, _ := opts.SMTP["auth"].(string)
	user, _ := opts.SMTP["user"].(string)
	password, _ := opts.SMTP["password"].(string)
	if authType != "" && user != "" {
		return smtp.PlainAuth("", user, password, opts.SMTP["host"].(string))
	}
	return nil
}
