package mbus

type JobState string

const (
	JobStateRunning JobState = "running"
)

type MemStat struct {
	Percent string `json:"percent,omitempty"`
	Kb      string `json:"kb,omitempty"`
}

type DiskStat struct {
	Percent      string `json:"percent,omitempty"`
	InodePercent string `json:"inode_percent,omitempty"`
}

type CpuPercent struct {
	User string `json:"user,omitempty"`
	Sys  string `json:"sys,omitempty"`
	Wait string `json:"wait,omitempty"`
}
type DiskStats struct {
	System     DiskStat `json:"system"`
	Ephemeral  DiskStat `json:"ephemeral"`
	Persistent DiskStat `json:"persistent"`
}

type Vitals struct {
	Load []string   `json:"load,omitempty"`
	Cpu  CpuPercent `json:"cpu"`
	Mem  MemStat    `json:"mem"`
	Swap MemStat    `json:"swap"`
	Disk DiskStats  `json:"disk"`
}

type Heartbeat struct {
	Job      string   `json:"job"`
	Index    int      `json:"index"`
	JobState JobState `json:"job_state"`
	Vitals   Vitals   `json:"vitals"`
}

//Heartbeat payload example:
//{
//  "job": "cloud_controller",
//  "index": 3,
//  "job_state":"running",
//  "vitals": {
//    "load": ["0.09","0.04","0.01"],
//    "cpu": {"user":"0.0","sys":"0.0","wait":"0.4"},
//    "mem": {"percent":"3.5","kb":"145996"},
//    "swap": {"percent":"0.0","kb":"0"},
//    "disk": {
//      "system": {"percent" => "82"},
//      "ephemeral": {"percent" => "5"},
//      "persistent": {"percent" => "94"}
//    },
//  "ntp": {
//      "offset": "-0.06423",
//      "timestamp": "14 Oct 11:13:19"
//  }
//}
