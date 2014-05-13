package syslog

import (
	"bufio"
	"net"
	"strconv"
	"sync"

	"github.com/jeromer/syslogparser/rfc3164"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
)

const concreteServerLogTag = "conreteServer"

type concreteServer struct {
	port   uint16
	logger boshlog.Logger

	l  net.Listener
	ll sync.Mutex
}

func NewServer(port uint16, logger boshlog.Logger) *concreteServer {
	return &concreteServer{port: port, logger: logger}
}

func (s *concreteServer) Start(callback CallbackFunc) error {
	var err error

	s.ll.Lock()

	s.l, err = net.Listen("tcp", ":"+strconv.Itoa(int(s.port)))
	if err != nil {
		s.ll.Unlock()
		return bosherr.WrapError(err, "Listening on port %d", s.port)
	}

	// Should not defer unlock since there is a long-running loop
	s.ll.Unlock()

	for {
		conn, err := s.l.Accept()
		if err != nil {
			return err
		}

		go s.handleConnection(conn, callback)
	}
}

func (s *concreteServer) Stop() error {
	s.ll.Lock()
	defer s.ll.Unlock()

	if s.l != nil {
		return s.l.Close()
	}

	return nil
}

func (s *concreteServer) handleConnection(conn net.Conn, callback CallbackFunc) {
	defer conn.Close()

	scanner := bufio.NewScanner(conn)

	for scanner.Scan() {
		bytes := scanner.Bytes()

		p := rfc3164.NewParser(bytes)

		err := p.Parse()
		if err != nil {
			s.logger.Error(
				concreteServerLogTag,
				"Failed to parse syslog message: %s error: %s",
				string(bytes), err.Error(),
			)
			continue
		}

		content, ok := p.Dump()["content"].(string)
		if !ok {
			s.logger.Error(
				concreteServerLogTag,
				"Failed to retrieve syslog message string content: %s",
				string(bytes),
			)
			continue
		}

		message := Msg{Content: content}

		callback(message)
	}

	err := scanner.Err()
	if err != nil {
		s.logger.Error(
			concreteServerLogTag,
			"Scanner error while parsing syslog message: %s",
			err.Error(),
		)
	}
}
