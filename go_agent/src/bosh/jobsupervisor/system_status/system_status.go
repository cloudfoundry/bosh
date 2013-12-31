package system_status

type SystemStatus struct {
	Load   SystemStatusLoad
	CPU    SystemStatusCPU
	Memory SystemStatusMemory
	Swap   SystemStatusSwap
}

type SystemStatusLoad struct {
	Avg01 float32
	Avg05 float32
	Avg15 float32
}

type SystemStatusCPU struct {
	User   float32
	System float32
}

type SystemStatusMemory struct {
	Percent  float32
	Kilobyte int
}

type SystemStatusSwap struct {
	Percent  float32
	Kilobyte int
}
