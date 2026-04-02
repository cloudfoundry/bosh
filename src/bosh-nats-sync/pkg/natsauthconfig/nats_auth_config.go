package natsauthconfig

import "fmt"

type VM struct {
	AgentID                 string `json:"agent_id"`
	PermanentNATSCredentials bool   `json:"permanent_nats_credentials"`
}

type Permissions struct {
	Publish   []string `json:"publish"`
	Subscribe []string `json:"subscribe"`
}

type User struct {
	User        string      `json:"user"`
	Permissions Permissions `json:"permissions"`
}

type Authorization struct {
	Users []User `json:"users"`
}

type AuthorizationConfig struct {
	Authorization Authorization `json:"authorization"`
}

func directorUser(subject string) User {
	return User{
		User: subject,
		Permissions: Permissions{
			Publish:   []string{"agent.*", "hm.director.alert"},
			Subscribe: []string{"director.>"},
		},
	}
}

func hmUser(subject string) User {
	return User{
		User: subject,
		Permissions: Permissions{
			Publish:   []string{},
			Subscribe: []string{"hm.agent.heartbeat.*", "hm.agent.alert.*", "hm.agent.shutdown.*", "hm.director.alert"},
		},
	}
}

func agentUser(agentID, cn string) User {
	return User{
		User: fmt.Sprintf("C=USA, O=Cloud Foundry, CN=%s.agent.bosh-internal", cn),
		Permissions: Permissions{
			Publish: []string{
				fmt.Sprintf("hm.agent.heartbeat.%s", agentID),
				fmt.Sprintf("hm.agent.alert.%s", agentID),
				fmt.Sprintf("hm.agent.shutdown.%s", agentID),
				fmt.Sprintf("director.*.%s.*", agentID),
			},
			Subscribe: []string{fmt.Sprintf("agent.%s", agentID)},
		},
	}
}

func CreateConfig(vms []VM, directorSubject, hmSubject *string) AuthorizationConfig {
	cfg := AuthorizationConfig{
		Authorization: Authorization{
			Users: []User{},
		},
	}

	if directorSubject != nil {
		cfg.Authorization.Users = append(cfg.Authorization.Users, directorUser(*directorSubject))
	}
	if hmSubject != nil {
		cfg.Authorization.Users = append(cfg.Authorization.Users, hmUser(*hmSubject))
	}

	for _, vm := range vms {
		if !vm.PermanentNATSCredentials {
			cfg.Authorization.Users = append(cfg.Authorization.Users, agentUser(vm.AgentID, vm.AgentID+".bootstrap"))
		}
		cfg.Authorization.Users = append(cfg.Authorization.Users, agentUser(vm.AgentID, vm.AgentID))
	}

	return cfg
}
