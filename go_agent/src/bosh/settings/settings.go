package settings

const (
	ROOT_USERNAME         = "root"
	VCAP_USERNAME         = "vcap"
	ADMIN_GROUP           = "admin"
	EPHEMERAL_USER_PREFIX = "bosh_"
)

type Settings struct {
	AgentId   string `json:"agent_id"`
	Blobstore Blobstore
	Disks     Disks
	Env       Env
	Networks  Networks
	Ntp       []string
	Mbus      string
	Vm        Vm
}

const (
	BlobstoreTypeDav   = "dav"
	BlobstoreTypeDummy = "dummy"
	BlobstoreTypeS3    = "s3"
	BlobstoreTypeLocal = "local"
)

type Blobstore struct {
	Type    string `json:"provider"`
	Options map[string]string
}

type Disks struct {
	System     string
	Ephemeral  string
	Persistent map[string]string
}

type Vm struct {
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
	Password string
}

type Networks map[string]Network

type Network struct {
	Default []string
	Dns     []string
	Ip      string
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

func (n Networks) DefaultIp() (ip string, found bool) {
	for _, networkSettings := range n {
		if ip == "" {
			ip = networkSettings.Ip
		}
		if len(networkSettings.Default) > 0 {
			ip = networkSettings.Ip
		}
	}

	if ip != "" {
		found = true
	}
	return
}

func (n Networks) Ips() (ips []string) {
	for _, net := range n {
		if net.Ip != "" {
			ips = append(ips, net.Ip)
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
