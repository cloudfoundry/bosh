package vitals

type Vitals struct {
	CPU  CPUVitals    `json:"cpu"`
	Disk DiskVitals   `json:"disk,omitempty"`
	Load []string     `json:"load,omitempty"`
	Mem  MemoryVitals `json:"mem"`
	Swap MemoryVitals `json:"swap"`
}

type CPUVitals struct {
	Sys  string `json:"sys,omitempty"`
	User string `json:"user,omitempty"`
	Wait string `json:"wait,omitempty"`
}

type DiskVitals map[string]SpecificDiskVitals

type SpecificDiskVitals struct {
	InodePercent string `json:"inode_percent,omitempty"`
	Percent      string `json:"percent,omitempty"`
}

type MemoryVitals struct {
	Kb      string `json:"kb,omitempty"`
	Percent string `json:"percent,omitempty"`
}
