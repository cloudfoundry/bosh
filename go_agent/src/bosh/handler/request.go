package handler

func NewRequest(replyTo, method string, payload []byte) Request {
	return Request{
		ReplyTo: replyTo,
		Method:  method,
		Payload: payload,
	}
}

type Request struct {
	ReplyTo string `json:"reply_to"`
	Method  string
	Payload []byte
}

func (r Request) GetPayload() []byte {
	return r.Payload
}
