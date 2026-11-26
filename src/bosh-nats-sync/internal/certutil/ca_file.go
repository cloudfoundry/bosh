package certutil

import (
	"fmt"
	"os"
	"strings"
)

func UsableCAFile(path string) (bool, error) {
	if path == "" {
		return false, nil
	}
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("cannot read CA certificate %q: %w", path, err)
	}
	return len(strings.TrimSpace(string(data))) > 0, nil
}
