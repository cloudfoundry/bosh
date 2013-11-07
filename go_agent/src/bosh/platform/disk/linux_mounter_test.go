package disk

import (
	testsys "bosh/system/testhelpers"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestLinuxMount(t *testing.T) {
	runner := &testsys.FakeCmdRunner{}

	mounter := NewLinuxMounter(runner)
	mounter.Mount("/dev/foo", "/mnt/foo")

	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{"mount", "/dev/foo", "/mnt/foo"}, runner.RunCommands[0])
}

func TestLinuxSwapOn(t *testing.T) {
	runner := &testsys.FakeCmdRunner{}

	mounter := NewLinuxMounter(runner)
	mounter.SwapOn("/dev/swap")

	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{"swapon", "/dev/swap"}, runner.RunCommands[0])
}
