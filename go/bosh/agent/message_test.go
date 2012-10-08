package agent

import (
	"encoding/json"
	"errors"
	. "launchpad.net/gocheck"
	"sync"
	"testing"
	"time"
)

func Test(t *testing.T) { TestingT(t) }

type mockMessage struct {
	subject string
	data    []byte
}

type mockMessageBus struct {
	lock sync.RWMutex
	sent []*mockMessage
}

func (p *mockMessageBus) Publish(subject string, data []byte) error {
	p.lock.Lock()
	defer p.lock.Unlock()
	p.sent = append(p.sent, &mockMessage{subject, data})
	return nil
}

type MessageSuite struct {
	nc     *mockMessageBus
	server *server
}

var _ = Suite(&MessageSuite{})

func (s *MessageSuite) SetUpTest(c *C) {
	s.nc = &mockMessageBus{}
	s.server = &server{}
}

func (s *MessageSuite) TearDownTest(c *C) {}

func (s *MessageSuite) TestParseMessageInvalidJSON(c *C) {
	_, err := ParseMessageFromJSON([]byte("hello world"))
	c.Check(err.Error(), Matches, "invalid JSON:.*")
}

func (s *MessageSuite) TestParseMessageValidJSON(c *C) {
	message := map[string]interface{}{
		"method":   "ping",
		"args":     []int{1, 2, 3},
		"reply_to": "foo.bar",
	}

	b, _ := json.Marshal(&message)
	m, err := ParseMessageFromJSON(b)

	c.Check(err, IsNil)
	c.Check(m.Method, Equals, "ping")
	c.Check(len(m.Args), Equals, 3)
	c.Check(m.Args[0], Equals, 1.0)
	c.Check(m.Args[1], Equals, 2.0)
	c.Check(m.Args[2], Equals, 3.0)
	c.Check(m.ReplySubject, Equals, "foo.bar")
}

func (s *MessageSuite) TestParseMessageMissingReplyChannel(c *C) {
	message := map[string]interface{}{
		"method": "ping",
	}

	b, _ := json.Marshal(&message)
	_, err := ParseMessageFromJSON(b)
	c.Check(err.Error(), Equals, "no reply channel provided")
}

func (s *MessageSuite) TestParseMessageNoMethod(c *C) {
	message := map[string]interface{}{
		"reply_to": "foobar",
	}

	b, _ := json.Marshal(&message)
	_, err := ParseMessageFromJSON(b)
	c.Check(err.Error(), Equals, "no method provided")
}

func (s *MessageSuite) TestParseMessageGetStateHandlerProperName(c *C) {
	message := map[string]interface{}{
		"method":   "get_state",
		"reply_to": "foo.bar",
	}

	b, _ := json.Marshal(&message)
	m, _ := ParseMessageFromJSON(b)

	c.Check(m.Method, Equals, "state")
}

func (s *MessageSuite) TestInvokeSimpleHandler(c *C) {
	Handlers["foo"] = func(s *server, args ...interface{}) (HandlerReturnValue, error) {
		return 123, nil
	}

	args := make([]interface{}, 1)
	m := NewMessage("foo", args, "foo.bar")
	m.Process(s.server, s.nc)

	c.Assert(len(s.nc.sent), Equals, 1)

	pubMsg := s.nc.sent[0]
	c.Check(pubMsg.subject, Equals, "foo.bar")

	r := NewHandlerResponse()
	err := json.Unmarshal(pubMsg.data, &r)

	c.Check(err, IsNil)
	c.Check(r.State, Equals, "done")
	c.Check(r.Value, Equals, 123.0)
	c.Check(r.Error, IsNil)
}

func (s *MessageSuite) TestGetTask(c *C) {
	barrier1 := make(chan bool, 1)
	barrier2 := make(chan bool, 1)

	ExclusiveHandlers["long_foo"] = func(s *server, args ...interface{}) (HandlerReturnValue, error) {
		<-barrier1
		return "bar", errors.New("something happened")
	}

	args := make([]interface{}, 1)
	lf := NewMessage("long_foo", args, "foo.bar")

	go func() {
		lf.Process(s.server, s.nc)
		barrier2 <- true
	}()

	for len(s.nc.sent) == 0 {
		// Give handler a little time to publish task id back
		time.Sleep(1 * time.Millisecond)
	}
	c.Assert(len(s.nc.sent), Equals, 1)

	resp := s.nc.sent[0]
	r := NewHandlerResponse()
	json.Unmarshal(resp.data, &r)
	c.Check(r.State, Equals, "running")
	c.Check(r.TaskId, NotNil)

	args = make([]interface{}, 1)
	args[0] = r.TaskId

	gt := NewMessage("get_task", args, "foo.bar")
	gt.Process(s.server, s.nc)

	c.Assert(len(s.nc.sent), Equals, 2)
	resp = s.nc.sent[1]
	r = NewHandlerResponse()
	json.Unmarshal(resp.data, &r)
	c.Check(r.State, Equals, "running")

	barrier1 <- true // allow handler to finish
	<-barrier2       // wait for handler processing to finish

	gt.Process(s.server, s.nc)

	c.Assert(len(s.nc.sent), Equals, 3)
	resp = s.nc.sent[2]
	r = NewHandlerResponse()
	json.Unmarshal(resp.data, &r)
	c.Check(r.State, Equals, "done")
	c.Check(r.Value, IsNil)
	c.Check(r.Error, Equals, "something happened")
}

func (s *MessageSuite) TestGetTaskInvalidHandlerArguments(c *C) {
	args := make([]interface{}, 0)

	gt := NewMessage("get_task", args, "foo.bar")
	gt.Process(s.server, s.nc)

	c.Assert(len(s.nc.sent), Equals, 1)
	resp := s.nc.sent[0]

	r := NewHandlerResponse()
	json.Unmarshal(resp.data, &r)
	c.Check(r.State, Equals, "done")
	c.Check(r.Error, Equals, "invalid arguments")
}

func (s *MessageSuite) TestUnknownTaskId(c *C) {
	args := make([]interface{}, 1)
	args[0] = "unknown_id"

	gt := NewMessage("get_task", args, "foo.bar")
	gt.Process(s.server, s.nc)

	c.Assert(len(s.nc.sent), Equals, 1)
	resp := s.nc.sent[0]

	r := NewHandlerResponse()
	json.Unmarshal(resp.data, &r)
	c.Check(r.State, Equals, "done")
	c.Check(r.Error, Equals, "unknown task id")
}

func (s *MessageSuite) TestMissingHandler(c *C) {
	ut := NewMessage("bar", make([]interface{}, 1), "foo.bar")
	ut.Process(s.server, s.nc)

	c.Assert(len(s.nc.sent), Equals, 1)
	resp := s.nc.sent[0]

	r := NewHandlerResponse()
	json.Unmarshal(resp.data, &r)
	c.Check(r.Error, Equals, "missing handler for 'bar'")
}

func (s *MessageSuite) TestCantRunMoreThanOneExclusiveTask(c *C) {
	barrier1 := make(chan bool, 1)
	barrier2 := make(chan bool, 1)

	ExclusiveHandlers["long_bar"] = func(s *server, args ...interface{}) (HandlerReturnValue, error) {
		<-barrier1
		return "bar", nil
	}

	args := make([]interface{}, 1)
	lb := NewMessage("long_bar", args, "foo.bar")

	go func() {
		lb.Process(s.server, s.nc)
		barrier2 <- true
	}()

	for len(s.nc.sent) == 0 {
		// Give handler a little time to publish task id back
		time.Sleep(1 * time.Millisecond)
	}
	c.Assert(len(s.nc.sent), Equals, 1)

	lb2 := NewMessage("long_bar", args, "foo.bar")
	lb2.Process(s.server, s.nc)
	c.Assert(len(s.nc.sent), Equals, 2)

	resp := s.nc.sent[1]

	r := NewHandlerResponse()
	json.Unmarshal(resp.data, &r)
	c.Check(r.State, Equals, "done")
	c.Check(r.Error, Equals, "exclusive task already running")

	pr := NewMessage("ping", args, "foo.bar")
	pr.Process(s.server, s.nc)
	c.Assert(len(s.nc.sent), Equals, 3)

	resp = s.nc.sent[2]

	r = NewHandlerResponse()
	json.Unmarshal(resp.data, &r)
	c.Check(r.State, Equals, "done")
	c.Check(r.Value, Equals, "pong")

	barrier1 <- true
	<-barrier2
}
