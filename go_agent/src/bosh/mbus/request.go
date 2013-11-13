package mbus

func NewRequest(replyTo, method, payload string) Request {
	return Request{
		ReplyTo: replyTo,
		Method:  method,
		payload: payload,
	}
}

type Request struct {
	ReplyTo string `json:"reply_to"`
	Method  string
	payload string
}

func (r Request) GetPayload() string {
	return r.payload
}
