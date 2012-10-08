package agent

import (
	"errors"
	"fmt"
	"github.com/apcera/nats"
	log "github.com/cihub/seelog"
	"os"
	"path"
)

const (
	MESSAGE_BACKLOG = 1024
)

type server struct {
	config    *Config
	messages  chan *message
	blobstore BlobstoreClient
	stateFile string
}

type Server interface {
	Start()
}

// Initializes a new server, sets up logging
func NewServer(cnf *Config) (*server, error) {
	s := &server{}
	s.config = cnf
	s.messages = make(chan *message, MESSAGE_BACKLOG)
	s.stateFile = path.Join(cnf.BaseDir, "state.json")

	var err error

	if s.blobstore, err = NewBlobstoreClient(cnf.Blobstore.Plugin, cnf.Blobstore.Options); err != nil {
		return nil, err
	}

	if err = s.initLogger(); err != nil {
		return nil, err
	}

	return s, nil
}

// Starts BOSH Agent, connects to NATS and sets up message receiving
func (s *server) Start() {
	var (
		subTopic = "agent." + s.config.AgentId
	)

	if s.config.ProductionMode {
		log.Infof("Running in production mode...")
	}

	nc, err := nats.Connect(s.config.MbusUri)
	if err != nil {
		log.Criticalf("Cannot connect to message bus: %s", err.Error())
		os.Exit(1)
	}
	defer nc.Close()

	log.Info("Connected to message bus...")
	log.Infof("Listening on '%s'", subTopic)

	nc.Subscribe(subTopic, func(m *nats.Msg) {
		if message, err := ParseMessageFromJSON(m.Data); err == nil {
			s.messages <- message
		} else {
			log.Errorf("Invalid message received (%s): %s", m.Data, err.Error())
		}
	})

	log.Info("Agent is running...")

	for {
		select {
		case message := <-s.messages:
			log.Infof("Received message: method=%s, args=%v'", message.Method, message.Args)
			go message.Process(s, nc)
		}
	}
}

func (s *server) initLogger() (err error) {
	logLevel, ok := log.LogLevelFromString(s.config.LogLevel)

	if !ok {
		return errors.New(fmt.Sprintf("invalid log level '%s'", s.config.LogLevel))
	}

	logger, err := log.LoggerFromWriterWithMinLevel(os.Stdout, logLevel)
	if err != nil {
		return err
	}

	log.ReplaceLogger(logger)
	return nil
}
