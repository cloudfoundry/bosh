package mbus

import boshvitals "bosh/platform/vitals"

type JobState string

const (
	JobStateRunning JobState = "running"
)

type Heartbeat struct {
	Job      string            `json:"job"`
	Index    int               `json:"index"`
	JobState JobState          `json:"job_state"`
	Vitals   boshvitals.Vitals `json:"vitals"`
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
