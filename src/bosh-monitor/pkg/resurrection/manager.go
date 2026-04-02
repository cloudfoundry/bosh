package resurrection

import (
	"crypto/sha256"
	"fmt"
	"log/slog"

	"gopkg.in/yaml.v3"
)

type Manager struct {
	parsedRules          []Rule
	logger               *slog.Logger
	resurrectionConfigSHA []string
}

func NewManager(logger *slog.Logger) *Manager {
	return &Manager{
		logger: logger,
	}
}

func (m *Manager) ResurrectionEnabled(deploymentName, instanceGroup string) bool {
	enabled := true
	for _, rule := range m.parsedRules {
		if rule.Applies(deploymentName, instanceGroup) {
			enabled = enabled && rule.Enabled
		}
	}
	return enabled
}

func (m *Manager) UpdateRules(resurrectionConfigs []map[string]interface{}) {
	if resurrectionConfigs == nil {
		return
	}

	var newSHAs []string
	for _, config := range resurrectionConfigs {
		content, _ := config["content"].(string)
		hash := fmt.Sprintf("%x", sha256.Sum256([]byte(content)))
		newSHAs = append(newSHAs, hash)
	}

	if shasEqual(m.resurrectionConfigSHA, newSHAs) {
		m.logger.Info("Resurrection config remains the same")
		return
	}

	m.logger.Info("Resurrection config update starting...")

	var newRules []Rule
	for _, config := range resurrectionConfigs {
		content, _ := config["content"].(string)
		var parsed struct {
			Rules []map[string]interface{} `yaml:"rules"`
		}
		if err := yaml.Unmarshal([]byte(content), &parsed); err != nil {
			m.logger.Error("Failed to parse resurrection config", "error", err)
			continue
		}
		for _, ruleHash := range parsed.Rules {
			rule, err := ParseRule(ruleHash)
			if err != nil {
				m.logger.Error("Failed to parse resurrection config rule", "rule", ruleHash, "error", err)
				continue
			}
			newRules = append(newRules, rule)
		}
	}

	m.parsedRules = newRules
	m.resurrectionConfigSHA = newSHAs
	m.logger.Info("Resurrection config update finished")
}

type Rule struct {
	Enabled       bool
	IncludeFilter Filter
	ExcludeFilter Filter
}

func ParseRule(data map[string]interface{}) (Rule, error) {
	enabledVal, ok := data["enabled"]
	if !ok {
		return Rule{}, fmt.Errorf("required property 'enabled' was not specified in object")
	}
	enabled, ok := enabledVal.(bool)
	if !ok {
		return Rule{}, fmt.Errorf("property 'enabled' value (%v) did not match the required type 'Boolean'", enabledVal)
	}

	includeData, _ := data["include"].(map[string]interface{})
	if includeData == nil {
		includeData = map[string]interface{}{}
	}
	excludeData, _ := data["exclude"].(map[string]interface{})
	if excludeData == nil {
		excludeData = map[string]interface{}{}
	}

	return Rule{
		Enabled:       enabled,
		IncludeFilter: ParseFilter(includeData, FilterTypeInclude),
		ExcludeFilter: ParseFilter(excludeData, FilterTypeExclude),
	}, nil
}

func (r Rule) Applies(deploymentName, instanceGroup string) bool {
	return r.IncludeFilter.Applies(deploymentName, instanceGroup) &&
		!r.ExcludeFilter.Applies(deploymentName, instanceGroup)
}

type FilterType int

const (
	FilterTypeInclude FilterType = iota
	FilterTypeExclude
)

type Filter struct {
	DeploymentNames []string
	InstanceGroups  []string
	Type            FilterType
}

func ParseFilter(data map[string]interface{}, filterType FilterType) Filter {
	f := Filter{Type: filterType}
	if deps, ok := data["deployments"]; ok {
		if depSlice, ok := deps.([]interface{}); ok {
			for _, d := range depSlice {
				f.DeploymentNames = append(f.DeploymentNames, fmt.Sprintf("%v", d))
			}
		}
	}
	if igs, ok := data["instance_groups"]; ok {
		if igSlice, ok := igs.([]interface{}); ok {
			for _, ig := range igSlice {
				f.InstanceGroups = append(f.InstanceGroups, fmt.Sprintf("%v", ig))
			}
		}
	}
	return f
}

func (f Filter) Applies(deploymentName, instanceGroup string) bool {
	if f.hasInstanceGroups() && !contains(f.InstanceGroups, instanceGroup) {
		return false
	}
	if f.hasDeployments() && !contains(f.DeploymentNames, deploymentName) {
		return false
	}
	if f.Type == FilterTypeInclude {
		return true
	}
	return f.hasAnyFilter()
}

func (f Filter) hasDeployments() bool {
	return len(f.DeploymentNames) > 0
}

func (f Filter) hasInstanceGroups() bool {
	return len(f.InstanceGroups) > 0
}

func (f Filter) hasAnyFilter() bool {
	return f.hasDeployments() || f.hasInstanceGroups()
}

func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}

func shasEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	aSet := make(map[string]bool, len(a))
	for _, s := range a {
		aSet[s] = true
	}
	for _, s := range b {
		if !aSet[s] {
			return false
		}
	}
	return true
}
