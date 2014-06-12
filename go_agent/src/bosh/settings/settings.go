package settings

const (
	RootUsername        = "root"
	VCAPUsername        = "vcap"
	AdminGroup          = "admin"
	EphemeralUserPrefix = "bosh_"
)

type Settings struct {
	AgentID   string    `json:"agent_id"`
	Blobstore Blobstore `json:"blobstore"`
	Disks     Disks     `json:"disks"`
	Env       Env       `json:"env"`
	Networks  Networks  `json:"networks"`
	Ntp       []string  `json:"ntp"`
	Mbus      string    `json:"mbus"`
	VM        VM        `json:"vm"`
}

const (
	BlobstoreTypeDummy = "dummy"
	BlobstoreTypeLocal = "local"
)

type Blobstore struct {
	Type    string                 `json:"provider"`
	Options map[string]interface{} `json:"options"`
}

type Disks struct {
	System     string            `json:"system"`
	Ephemeral  string            `json:"ephemeral"`
	Persistent map[string]string `json:"persistent"`
}

type VM struct {
	Name string `json:"name"`
}

func (d Disks) PersistentDiskPath() (path string) {
	for _, path = range d.Persistent {
		return
	}
	return
}

type Env struct {
	Bosh BoshEnv `json:"bosh"`
}

func (e Env) GetPassword() string {
	return e.Bosh.Password
}

type BoshEnv struct {
	Password string `json:"password"`
}

type Networks map[string]Network

type NetworkType string

const (
	NetworkTypeDynamic NetworkType = "dynamic"
)

type Network struct {
	Type NetworkType `json:"type"`

	IP      string `json:"ip"`
	Netmask string `json:"netmask"`
	Gateway string `json:"gateway"`

	Default []string `json:"default"`
	DNS     []string `json:"dns"`

	Mac string `json:"mac"`
}

func (n Networks) DefaultNetworkFor(category string) (network Network, found bool) {
	if len(n) == 0 {
		return
	}

	if len(n) == 1 {
		found = true
	}

	for _, net := range n {
		for _, def := range net.Default {
			if def == category {
				found = true
			}
		}
		if found {
			network = net
			return
		}
	}

	return
}

func (n Networks) DefaultIP() (ip string, found bool) {
	for _, networkSettings := range n {
		if ip == "" {
			ip = networkSettings.IP
		}
		if len(networkSettings.Default) > 0 {
			ip = networkSettings.IP
		}
	}

	if ip != "" {
		found = true
	}
	return
}

func (n Networks) IPs() (ips []string) {
	for _, net := range n {
		if net.IP != "" {
			ips = append(ips, net.IP)
		}
	}
	return
}

func (n Network) IsDynamic() bool {
	return n.Type == NetworkTypeDynamic
}

//{
//	"agent_id": "bm-xxxxxxxx",
//	"blobstore": {
//		"options": {
//			"blobstore_path": "/var/vcap/micro_bosh/data/cache"
//		},
//		"provider": "local"
//	},
//	"disks": {
//		"ephemeral": "/dev/sdb",
//		"persistent": {
//			"vol-xxxxxx": "/dev/sdf"
//		},
//		"system": "/dev/sda1"
//	},
//	"env": {
//		"bosh": {
//			"password": null
//		}
//	},
//	"mbus": "https://vcap:b00tstrap@0.0.0.0:6868",
//	"networks": {
//		"bosh": {
//			"cloud_properties": {
//				"subnet": "subnet-xxxxxx"
//			},
//			"default": [
//				"dns",
//				"gateway"
//			],
//			"dns": [
//				"xx.xx.xx.xx"
//			],
//			"gateway": null,
//			"ip": "xx.xx.xx.xx",
//			"netmask": null,
//			"type": "manual"
//		},
//		"vip": {
//			"cloud_properties": {},
//			"ip": "xx.xx.xx.xx",
//			"type": "vip"
//		}
//	},
//	"ntp": [
//		"0.north-america.pool.ntp.org",
//		"1.north-america.pool.ntp.org",
//		"2.north-america.pool.ntp.org",
//		"3.north-america.pool.ntp.org"
//	],
//	"vm": {
//		"name": "vm-xxxxxxxx"
//	}
//}
