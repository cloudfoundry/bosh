package applyspec

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestMaxLogFileSize(t *testing.T) {
	// No 'properties'
	applySpec, err := NewApplySpecFromData(
		map[string]interface{}{},
	)
	assert.NoError(t, err)
	assert.Equal(t, "50M", applySpec.MaxLogFileSize())

	// No 'logging' in properties
	applySpec, err = NewApplySpecFromData(
		map[string]interface{}{
			"properties": map[string]interface{}{},
		},
	)
	assert.NoError(t, err)
	assert.Equal(t, "50M", applySpec.MaxLogFileSize())

	// No 'max_log_file_size' in logging
	applySpec, err = NewApplySpecFromData(
		map[string]interface{}{
			"properties": map[string]interface{}{
				"logging": map[string]interface{}{},
			},
		},
	)
	assert.NoError(t, err)
	assert.Equal(t, "50M", applySpec.MaxLogFileSize())

	// Specified 'max_log_file_size'
	applySpec, err = NewApplySpecFromData(
		map[string]interface{}{
			"properties": map[string]interface{}{
				"logging": map[string]interface{}{
					"max_log_file_size": "fake-size",
				},
			},
		},
	)
	assert.NoError(t, err)
	assert.Equal(t, "fake-size", applySpec.MaxLogFileSize())
}
