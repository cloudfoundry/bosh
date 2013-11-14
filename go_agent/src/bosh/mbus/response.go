package mbus

type Response struct {
	Value     interface{} `json:"value,omitempty"`
	Exception string      `json:"exception,omitempty"`
}
