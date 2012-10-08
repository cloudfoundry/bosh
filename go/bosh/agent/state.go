package agent

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"syscall"
)

// Agent state is pretty much opaque to Agent most of the time
type state map[string]interface{}

var (
	DefaultState = map[string]interface{}{
		"deployment":    "",
		"networks":      map[string]interface{}{},
		"resource_pool": map[string]interface{}{},
	}
)

func ReadStateFromJSON(s string) (state, error) {
	st := make(map[string]interface{})

	if err := json.Unmarshal([]byte(s), &st); err != nil {
		return nil, fmt.Errorf("invalid json: %s", err.Error())
	}

	return st, nil
}

func ReadStateFromFile(s *server) (state, error) {
	f, err := os.Open(s.stateFile)
	if os.IsNotExist(err) {
		return DefaultState, nil
	}
	if err != nil {
		return nil, err
	}
	defer f.Close()

	if err = syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		return nil, err
	}
	defer syscall.Flock(int(f.Fd()), syscall.LOCK_UN)

	b, err := ioutil.ReadAll(f)
	if err != nil {
		return nil, err
	}

	return ReadStateFromJSON(string(b))
}

func WriteState(s *server, newState state) error {
	b, err := json.Marshal(newState)
	if err != nil {
		return err
	}

	f, err := os.Create(s.stateFile)
	if err != nil {
		return err
	}

	if err = syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		return err
	}
	defer syscall.Flock(int(f.Fd()), syscall.LOCK_UN)

	if _, err = f.Write(b); err != nil {
		return err
	}

	return nil
}
