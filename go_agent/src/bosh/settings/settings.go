package settings

type Settings struct {
	AgentId  string `json:"agent_id"`
	Disks    Disks
	Env      Env
	Networks Networks
	Ntp      []string
	Mbus     string
}

type Env struct {
	Bosh BoshEnv `json:"bosh"`
}

func (e Env) GetPassword() string {
	return e.Bosh.Password
}

type BoshEnv struct {
	Password string
}

type Disks struct {
	System     string
	Ephemeral  string
	Persistent map[string]string
}

func (d Disks) PersistentDiskPath() (path string) {
	for _, path = range d.Persistent {
		return
	}
	return
}

type Networks map[string]NetworkSettings

type NetworkSettings struct {
	Default []string
	Dns     []string
}

func (n Networks) DefaultNetworkFor(category string) (settings NetworkSettings, found bool) {
	if len(n) == 0 {
		return
	}

	if len(n) == 1 {
		found = true
	}

	for _, networkSettings := range n {
		for _, def := range networkSettings.Default {
			if def == category {
				found = true
			}
		}
		if found {
			settings = networkSettings
			return
		}
	}

	return
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
