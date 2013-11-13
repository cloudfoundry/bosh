package mbus

func NewRequest(replyTo, method string, payload []byte) Request {
	return Request{
		ReplyTo: replyTo,
		Method:  method,
		payload: payload,
	}
}

type Request struct {
	ReplyTo string `json:"reply_to"`
	Method  string
	payload []byte
}

func (r Request) GetPayload() []byte {
	return r.payload
}
