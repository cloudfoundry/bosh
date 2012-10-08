package agent

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"net"
	"path"
	"strconv"
)

// Here's an example of what settings.json currently looks like for vSphere CPI:
/*
  {
    "agent_id": "4365a995-ce3e-4013-9207-c6791828655d",
    "mbus": "nats://natsUser:natsPassword@172.20.133.17:4222",

    "vm": {
      "name": "vm-98ec3f07-33de-4b86-8e31-7e1578b7cdc8",
      "id": "vm-3450"
    },

    "networks": {
      "default": {
        "ip": "172.20.182.54",
        "netmask": "255.255.254.0",
        "cloud_properties": {
          "name":"VLAN2310"
        },
        "default": ["dns","gateway"],
        "dns": ["172.22.22.153","172.22.22.154"],
        "gateway": "172.20.182.1",
        "mac": "00:50:56:84:1d:4b"
      }
    },

    "disks": {
      "system": 0,
      "ephemeral": 1,
      "persistent": {
        "90": 2
      }
    },

    "ntp": ["172.22.22.4","172.22.22.5"],

    "blobstore": {
      "plugin": "simple",
      "properties":{
        "endpoint": "http://172.20.133.21:25251",
        "user": "agent",
        "password": "secret"
      }
    },

    "env": {
      "bosh": {
        "password": "crypted password"
      }
    }
  }
*/

type Config struct {
	ProductionMode bool
	ConfigPath     string
	BaseDir        string
	LogLevel       string
	Infrastructure string
	Platform       string

	AgentId       string                    `json:"agent_id"`
	MbusUri       string                    `json:"mbus"`
	Vm            VmConfig                  `json:"vm"`
	Networks      map[string]*NetworkConfig `json:"networks"`
	Blobstore     BlobstoreConfig           `json:"blobstore"`
	NtpServers    []string                  `json:"ntp"`
	Env           map[string]interface{}    `json:"env"`
	RawDiskConfig map[string]interface{}    `json:"disks"`

	SystemDisk      string
	EphemeralDisk   string
	PersistentDisks map[string]string
}

type VmConfig struct {
	Name string `json:"name"`
	Id   string `json:"id"`
}

type NetworkConfig struct {
	NetType         string `json:"type"`
	IpString        string `json:"ip"`
	Ip              net.IP
	NetmaskString   string `json:"netmask"`
	Netmask         net.IPMask
	GatewayString   string `json:"gateway"`
	Gateway         net.IP
	Dns             []string `json:"dns"`
	MacString       string   `json:"mac"`
	Mac             net.HardwareAddr
	Defaults        []string               `json:"default"`
	CloudProperties map[string]interface{} `json:"cloud_properties"`
}

type BlobstoreConfig struct {
	Plugin  string                 `json:"plugin"`
	Options map[string]interface{} `json:"properties"`
}

type DiskConfig struct {
	id         string
	deviceName string
}

// Parses command line flags provided for the current process, finds configuration
// file (provided via '-c') and loads configuration from that file. Returns
// a new agent config data structure. Sets an error if provided flags and/or config
// are not valid.
func LoadConfig() (cnf *Config, err error) {
	cnf = &Config{}
	cnf.BaseDir = "/var/vcap/bosh"

	flag.BoolVar(&cnf.ProductionMode, "p", false, "Run in production mode")
	flag.StringVar(&cnf.ConfigPath, "c", path.Join(cnf.BaseDir, "settings.json"), "Config path")
	flag.StringVar(&cnf.Infrastructure, "i", "", "Infrastructure name")
	flag.StringVar(&cnf.LogLevel, "l", "debug", "Log level")

	flag.Parse()

	if len(cnf.Infrastructure) == 0 {
		return nil, errors.New("please provide infrastructure name via '-i' flag")
	}

	b, err := ioutil.ReadFile(cnf.ConfigPath)
	if err != nil {
		return nil, err
	}

	// Agent configuration is very opaque, so using an intermediate data structure
	// seems to be the right thing to do.
	if err = json.Unmarshal(b, &cnf); err != nil {
		return nil, fmt.Errorf("invalid JSON: %s", err.Error())
	}

	if len(cnf.AgentId) == 0 {
		return nil, errors.New("missing agent id")
	}

	if len(cnf.MbusUri) == 0 {
		return nil, errors.New("missing message bus URI")
	}

	if len(cnf.Blobstore.Plugin) == 0 {
		return nil, errors.New("missing blobstore plugin")
	}

	for networkName, network := range cnf.Networks {
		if len(network.IpString) > 0 {
			network.Ip = net.ParseIP(network.IpString)
			if network.Ip == nil {
				return nil, fmt.Errorf("invalid IP for network '%s'", networkName)
			}
		}
		if len(network.NetmaskString) > 0 {
			maskBytes := net.ParseIP(network.NetmaskString)
			if maskBytes == nil {
				return nil, fmt.Errorf("invalid netmask for network '%s'", networkName)
			}
			network.Netmask = net.IPMask(maskBytes)
		}
		if len(network.MacString) > 0 {
			network.Mac, err = net.ParseMAC(network.MacString)
			if err != nil {
				return nil, fmt.Errorf("invalid MAC for network '%s'", networkName)
			}
		}
		if len(network.GatewayString) > 0 {
			network.Gateway = net.ParseIP(network.GatewayString)
			if network.Gateway == nil {
				return nil, fmt.Errorf("invalid gateway for network '%s'", networkName)
			}
		}
	}

	if err = cnf.parseDisksConfig(); err != nil {
		return nil, err
	}

	if len(cnf.SystemDisk) == 0 {
		return nil, errors.New("no system disk specifed")
	}
	if len(cnf.EphemeralDisk) == 0 {
		return nil, errors.New("no ephemeral disk specified")
	}

	return cnf, nil
}

func (c *Config) parseDisksConfig() error {
	for diskType, diskInfo := range c.RawDiskConfig {
		switch diskType {
		case "system":
			deviceId, err := stringDeviceId(diskInfo)
			if err != nil {
				return fmt.Errorf("invalid system disk, %s", err.Error())
			}
			c.SystemDisk = deviceId
		case "ephemeral":
			deviceId, err := stringDeviceId(diskInfo)
			if err != nil {
				return fmt.Errorf("invalid ephemeral disk, %s", err.Error())
			}
			c.EphemeralDisk = deviceId
		case "persistent":
			persistentDisks, ok := diskInfo.(map[string]interface{})
			if !ok {
				return errors.New("invalid persistent disk mapping")
			}
			c.PersistentDisks = make(map[string]string)
			for diskId, dev := range persistentDisks {
				deviceId, err := stringDeviceId(dev)
				if err != nil {
					return fmt.Errorf("invalid persistent disk, %s", err.Error())
				}
				c.PersistentDisks[diskId] = deviceId
			}
		default:
			return fmt.Errorf("invalid disk type '%s'", diskType)
		}
	}
	return nil
}

// vSphere CPI uses integer device ids (SCSI bus indices),
// other CPIs use UNIX device names: we have to support both
func stringDeviceId(deviceId interface{}) (string, error) {
	// Golang JSON module treats all numbers as float64
	if dev, isNumber := deviceId.(float64); isNumber {
		return strconv.Itoa(int(dev)), nil
	} else if dev, isString := deviceId.(string); isString {
		return dev, nil
	}
	return "", errors.New("bad device id, string or int expected")
}
