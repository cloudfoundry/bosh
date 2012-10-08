package agent

import (
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	log "github.com/cihub/seelog"
	"sync"
)

// Incoming RPC call
type message struct {
	Method       string        `json:"method"`
	Args         []interface{} `json:"args"`
	ReplySubject string        `json:"reply_to"`
}

// RPC Response
type handlerResponse struct {
	TaskId string `json:"agent_task_id,omitempty"`
	State  string `json:"state,omitempty"`

	Value HandlerReturnValue `json:"value,omitempty"`
	Error HandlerErrorValue  `json:"exception,omitempty"`
}

type ResponsePublisher interface {
	Publish(subj string, data []byte) error
}

var (
	NoReplyChannel   = errors.New("no reply channel provided")
	NoMethod         = errors.New("no method provided")
	UnknownTaskId    = &handlerResponse{State: "done", Error: "unknown task id"}
	InvalidArguments = &handlerResponse{State: "done", Error: "invalid arguments"}

	// Multiple regular handlers can run at the same time
	Handlers = map[string]MessageHandler{
		"ping":  PingHandler,
		"state": GetStateHandler,
	}

	// Only one exclusive handler can run at the same time
	runLock           = make(chan bool, 1)
	ExclusiveHandlers = map[string]MessageHandler{
		"apply": ApplyHandler,
	}

	// Keeping track of tasks
	// TODO: needs to be bounded
	responseLock = &sync.RWMutex{}
	Responses    = make(map[string]*handlerResponse)
)

func NewMessage(method string, args []interface{}, replySubject string) *message {
	return &message{Method: method, Args: args, ReplySubject: replySubject}
}

func NewHandlerResponse() *handlerResponse {
	return &handlerResponse{}
}

// Parses incoming JSON and creates a new message from it.
func ParseMessageFromJSON(data []byte) (*message, error) {
	m := new(message)
	err := json.Unmarshal(data, &m)

	if err != nil {
		return m, fmt.Errorf("invalid JSON: %s", err.Error())
	} else {
		if len(m.ReplySubject) == 0 {
			return m, NoReplyChannel
		}
		if len(m.Method) == 0 {
			return m, NoMethod
		}
	}

	if m.Method == "get_state" {
		m.Method = "state"
	}

	return m, nil
}

func (m *message) Process(s *server, p ResponsePublisher) {
	err := m.invokeHandler(s, p)
	if err != nil {
		log.Errorf("Unable to invoke handler for '%s': %s", m.Method, err.Error())
	}
}

func (m *message) invokeHandler(s *server, p ResponsePublisher) error {
	if m.Method == "get_task" {
		m.processGetTask(p)
		return nil
	}

	resp := &handlerResponse{}

	handler, exclusive := ExclusiveHandlers[m.Method]
	if !exclusive {
		var ok bool
		handler, ok = Handlers[m.Method]
		if !ok {
			resp.State = "done"
			resp.Error = fmt.Sprintf("missing handler for '%s'", m.Method)
			m.publishResponse(p, resp)
			return nil
		}
	}

	if exclusive {
		select {
		case runLock <- true:
			log.Infof("Exclusive handler for '%s' has started", m.Method)
			defer func() {
				log.Infof("'%s' handler has finished, can schedule a new exclusive task", m.Method)
				<-runLock
			}()
		default:
			resp.State = "done"
			resp.Error = "exclusive task already running"
			m.publishResponse(p, resp)
			return nil
		}

		taskId, err := generateUUID()
		if err != nil {
			return fmt.Errorf("can't generate task id: %s", err.Error())
		}
		resp.State = "running"
		resp.TaskId = taskId

		func() {
			responseLock.Lock()
			defer responseLock.Unlock()
			Responses[taskId] = resp
			log.Debugf("Total exclusive tasks processed: %d", len(Responses))
		}()

		m.publishResponse(p, resp)
	}

	value, err := MessageHandler(handler).HandleMessage(s, m.Args...)
	if err == nil {
		resp.Value = value
	} else {
		resp.Error = err.Error()
	}
	resp.State = "done"

	// Exclusive handler responses will be collected by get_task calls,
	// so we only care to publish response if it's not an exclusive task.
	if !exclusive {
		m.publishResponse(p, resp)
	}

	return nil
}

func (m *message) processGetTask(p ResponsePublisher) {
	if len(m.Args) != 1 {
		m.publishResponse(p, InvalidArguments)
		return
	}

	taskId, ok := m.Args[0].(string)

	if !ok {
		m.publishResponse(p, InvalidArguments)
		return
	}

	responseLock.Lock()
	defer responseLock.Unlock()
	resp, ok := Responses[taskId]
	if ok {
		m.publishResponse(p, resp)
	} else {
		m.publishResponse(p, UnknownTaskId)
	}
}

func (m *message) publishResponse(p ResponsePublisher, resp *handlerResponse) {
	b, err := json.Marshal(resp)
	if err != nil {
		log.Errorf("Cannot generate JSON from handler response: %s", err.Error())
		return
	}

	err = p.Publish(m.ReplySubject, b)
	if err != nil {
		log.Errorf("Cannot publish response: %s", err.Error())
	}
	log.Infof("Published response to '%s': %s", m.Method, b)
	return
}

// TODO: properly set UUIDv4 bits
func generateUUID() (string, error) {
	b := make([]byte, 16)
	n, err := rand.Read(b)
	if n != len(b) || err != nil {
		return "", err
	}
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:]), nil
}
