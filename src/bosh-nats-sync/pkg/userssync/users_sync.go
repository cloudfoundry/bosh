package userssync

import (
	"crypto/md5"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"strings"
	"time"

	"bosh-nats-sync/pkg/authprovider"
	"bosh-nats-sync/pkg/config"
	"bosh-nats-sync/pkg/natsauthconfig"
)

const (
	httpSuccess                          = 200
	defaultDirectorConnectionWaitTimeout = 60
	defaultDirectorConnectionRetryInterval = 1 * time.Second
)

type CommandRunner func(executable string, args ...string) ([]byte, error)

func DefaultCommandRunner(executable string, args ...string) ([]byte, error) {
	cmd := exec.Command(executable, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return output, fmt.Errorf("cannot execute: %s %s, Error: %s", executable, strings.Join(args, " "), string(output))
	}
	return output, nil
}

type UsersSync struct {
	NATSConfigFilePath    string
	BoshConfig            config.DirectorConfig
	NATSServerExecutable  string
	NATSServerPIDFile     string
	Logger                *slog.Logger
	CommandRunner         CommandRunner
}

func (u *UsersSync) getCommandRunner() CommandRunner {
	if u.CommandRunner != nil {
		return u.CommandRunner
	}
	return DefaultCommandRunner
}

func (u *UsersSync) Execute() error {
	u.Logger.Info("Executing NATS Users Synchronization")

	var vms []natsauthconfig.VM
	overwriteableConfigFile := true

	err := u.withDirectorConnection(func() error {
		var queryErr error
		vms, queryErr = u.queryAllRunningVMs()
		return queryErr
	})

	if err != nil {
		u.Logger.Error("Could not query all running vms", "error", err)
		overwriteableConfigFile = u.userFileOverwritable()
		if overwriteableConfigFile {
			u.Logger.Info("NATS config file is empty, writing basic users config file.")
		} else {
			u.Logger.Info("NATS config file is not empty, doing nothing.")
		}
	}

	if overwriteableConfigFile {
		currentFileHash := u.natsFileHash()

		directorSubject := readSubjectFile(u.BoshConfig.DirectorSubjectFile)
		hmSubject := readSubjectFile(u.BoshConfig.HMSubjectFile)

		if writeErr := u.writeNATSConfigFile(vms, directorSubject, hmSubject); writeErr != nil {
			return writeErr
		}

		newFileHash := u.natsFileHash()
		if currentFileHash != newFileHash {
			if reloadErr := ReloadNATSServerConfig(u.NATSServerExecutable, u.NATSServerPIDFile, u.getCommandRunner()); reloadErr != nil {
				return reloadErr
			}
		}
	}

	u.Logger.Info("Finishing NATS Users Synchronization")
	return nil
}

func ReloadNATSServerConfig(executable, pidFile string, runner CommandRunner) error {
	arg := fmt.Sprintf("reload=%s", pidFile)
	_, err := runner(executable, "--signal", arg)
	return err
}

func (u *UsersSync) withDirectorConnection(fn func() error) error {
	timeout := u.BoshConfig.ConnectionWaitTimeout
	if timeout <= 0 {
		timeout = defaultDirectorConnectionWaitTimeout
	}

	maxAttempts := timeout / int(defaultDirectorConnectionRetryInterval.Seconds())
	if maxAttempts < 1 {
		maxAttempts = 1
	}

	var lastErr error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		_, lastErr = u.boshAPIResponseBody("/info", false)
		if lastErr == nil {
			return fn()
		}

		if isConnectionError(lastErr) {
			u.Logger.Info(fmt.Sprintf("Waiting for director API to become available (attempt %d/%d): %s", attempt, maxAttempts, lastErr))
			if attempt < maxAttempts {
				time.Sleep(defaultDirectorConnectionRetryInterval)
			}
			continue
		}
		return lastErr
	}
	return lastErr
}

func isConnectionError(err error) bool {
	if err == nil {
		return false
	}
	errStr := err.Error()
	connectionErrors := []string{
		"connection refused",
		"connection reset",
		"timed out",
		"host is unreachable",
		"network is unreachable",
		"no such host",
		"i/o timeout",
	}
	for _, ce := range connectionErrors {
		if strings.Contains(strings.ToLower(errStr), ce) {
			return true
		}
	}
	return false
}

func (u *UsersSync) userFileOverwritable() bool {
	data, err := os.ReadFile(u.NATSConfigFilePath)
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
	info, err := os.Stat(filePath)
	if err != nil || info.Size() == 0 {
		return nil
	}
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
	data, err := os.ReadFile(u.NATSConfigFilePath)
	if err != nil {
		return ""
	}
	return fmt.Sprintf("%x", md5.Sum(data))
}

func (u *UsersSync) boshAPIResponseBody(apiPath string, auth bool) ([]byte, error) {
	fullURL := u.BoshConfig.URL + apiPath
	parsed, err := url.Parse(fullURL)
	if err != nil {
		return nil, fmt.Errorf("invalid URL: %s", fullURL)
	}

	client := &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: parsed.Scheme == "https"},
		},
		Timeout: 30 * time.Second,
	}

	req, err := http.NewRequest("GET", fullURL, nil)
	if err != nil {
		return nil, err
	}

	if auth {
		header, err := u.getAuthHeader()
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
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != httpSuccess {
		return nil, fmt.Errorf("cannot access: %s, Status Code: %d, %s", apiPath, resp.StatusCode, string(body))
	}

	return body, nil
}

func (u *UsersSync) getAuthHeader() (string, error) {
	infoBody, err := u.boshAPIResponseBody("/info", false)
	if err != nil {
		return "", err
	}

	info, err := authprovider.ParseInfoResponse(infoBody)
	if err != nil {
		return "", err
	}

	provider := authprovider.New(info, u.BoshConfig, u.Logger)
	return provider.AuthHeader()
}

type deployment struct {
	Name string `json:"name"`
}

func (u *UsersSync) queryAllDeployments() ([]string, error) {
	body, err := u.boshAPIResponseBody("/deployments", true)
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

func (u *UsersSync) getVMsByDeployment(deploymentName string) ([]natsauthconfig.VM, error) {
	body, err := u.boshAPIResponseBody(fmt.Sprintf("/deployments/%s/vms", deploymentName), true)
	if err != nil {
		return nil, err
	}

	var vms []natsauthconfig.VM
	if err := json.Unmarshal(body, &vms); err != nil {
		return nil, err
	}
	return vms, nil
}

func (u *UsersSync) queryAllRunningVMs() ([]natsauthconfig.VM, error) {
	deploymentNames, err := u.queryAllDeployments()
	if err != nil {
		return nil, err
	}

	var allVMs []natsauthconfig.VM
	for _, name := range deploymentNames {
		vms, err := u.getVMsByDeployment(name)
		if err != nil {
			return nil, err
		}
		allVMs = append(allVMs, vms...)
	}
	return allVMs, nil
}

func (u *UsersSync) writeNATSConfigFile(vms []natsauthconfig.VM, directorSubject, hmSubject *string) error {
	cfg := natsauthconfig.CreateConfig(vms, directorSubject, hmSubject)
	data, err := json.Marshal(cfg)
	if err != nil {
		return err
	}
	return os.WriteFile(u.NATSConfigFilePath, data, 0644)
}
