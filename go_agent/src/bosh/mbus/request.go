package mbus

type Request struct {
	ReplyTo string `json:"reply_to"`
	Method  string
	Args    []string `json:"arguments"`
}
