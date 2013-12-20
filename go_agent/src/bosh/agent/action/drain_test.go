package action

import (
	boshas "bosh/agent/applier/applyspec"
	boshassert "bosh/assert"
	fakenotif "bosh/notification/fakes"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
	"encoding/json"
	"errors"
	"github.com/stretchr/testify/assert"
	"path/filepath"
	"testing"
)

func TestDrainShouldBeAsynchronous(t *testing.T) {
	_, _, _, action := buildDrain()
	assert.True(t, action.IsAsynchronous())
}

func TestDrainRunUpdateSkipsDrainScriptWhenWithoutDrainScript(t *testing.T) {
	currentSpec := boshas.V1ApplySpec{}
	currentSpec.JobSpec.Template = "foo"

	scriptPath := filepath.Join("/var/vcap", currentSpec.JobSpec.Template, "bin", "drain")

	runner, fs, _, action := buildDrain()

	fs.WriteToFile("/var/vcap/bosh/spec.json", marshalSpecForTests(currentSpec))
	fs.RemoveAll(scriptPath)

	newSpec := boshas.V1ApplySpec{
		PackageSpecs: map[string]boshas.PackageSpec{
			"foo": boshas.PackageSpec{
				Name: "foo",
				Sha1: "foo-sha1-new",
			},
		},
	}
	_, err := action.Run(drainTypeUpdate, newSpec)
	assert.NoError(t, err)
	assert.Equal(t, 0, len(runner.RunComplexCommands))
}

func TestDrainRunShutdownSkipsDrainScriptWhenWithoutDrainScript(t *testing.T) {
	currentSpec := boshas.V1ApplySpec{}
	currentSpec.JobSpec.Template = "foo"

	scriptPath := filepath.Join("/var/vcap", currentSpec.JobSpec.Template, "bin", "drain")

	runner, fs, _, action := buildDrain()

	fs.WriteToFile("/var/vcap/bosh/spec.json", marshalSpecForTests(currentSpec))
	fs.RemoveAll(scriptPath)

	newSpec := boshas.V1ApplySpec{
		PackageSpecs: map[string]boshas.PackageSpec{
			"foo": boshas.PackageSpec{
				Name: "foo",
				Sha1: "foo-sha1-new",
			},
		},
	}
	_, err := action.Run(drainTypeShutdown, newSpec)
	assert.NoError(t, err)
	assert.Equal(t, 0, len(runner.RunComplexCommands))
}

func TestDrainRunStatusErrsWhenWithoutDrainScript(t *testing.T) {
	currentSpec := boshas.V1ApplySpec{}
	currentSpec.JobSpec.Template = "foo"

	scriptPath := filepath.Join("/var/vcap", currentSpec.JobSpec.Template, "bin", "drain")

	_, fs, _, action := buildDrain()

	fs.WriteToFile("/var/vcap/bosh/spec.json", marshalSpecForTests(currentSpec))
	fs.RemoveAll(scriptPath)

	_, err := action.Run(drainTypeStatus)
	assert.Error(t, err)
}

func TestDrainReturnsIntegerValueOfDrainscriptStdoutAfterTrimmingWhitespace(t *testing.T) {
	cmdRunner, fs, _, action := buildDrain()

	currentSpec := boshas.V1ApplySpec{}
	currentSpec.JobSpec.Template = "foo"
	fs.WriteToFile("/var/vcap/bosh/spec.json", marshalSpecForTests(currentSpec))

	drainScriptPath := filepath.Join("/var/vcap/jobs", currentSpec.JobSpec.Template, "bin", "drain")
	fs.WriteToFile(drainScriptPath, "")
	cmdRunner.AddCmdResult(drainScriptPath+" job_check_status hash_unchanged", fakesys.FakeCmdResult{Stdout: "-56\n"})

	value, err := action.Run(drainTypeStatus)
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, value, "-56")
}

func TestDrainErrsWhenDrainscriptStdoutIsNotSignedInteger(t *testing.T) {
	cmdRunner, fs, _, action := buildDrain()

	currentSpec := boshas.V1ApplySpec{}
	currentSpec.JobSpec.Template = "foo"
	fs.WriteToFile("/var/vcap/bosh/spec.json", marshalSpecForTests(currentSpec))

	drainScriptPath := filepath.Join("/var/vcap/jobs", currentSpec.JobSpec.Template, "bin", "drain")
	fs.WriteToFile(drainScriptPath, "")
	cmdRunner.AddCmdResult(drainScriptPath+" job_check_status hash_unchanged", fakesys.FakeCmdResult{Stdout: "not a number"})

	_, err := action.Run(drainTypeStatus)
	assert.Error(t, err)
}

func TestDrainErrsWhenDrainscriptExitsNonZero(t *testing.T) {
	cmdRunner, fs, _, action := buildDrain()

	currentSpec := boshas.V1ApplySpec{}
	currentSpec.JobSpec.Template = "foo"
	fs.WriteToFile("/var/vcap/bosh/spec.json", marshalSpecForTests(currentSpec))

	drainScriptPath := filepath.Join("/var/vcap/jobs", currentSpec.JobSpec.Template, "bin", "drain")
	fs.WriteToFile(drainScriptPath, "")
	cmdRunner.AddCmdResult(drainScriptPath+" job_check_status hash_unchanged", fakesys.FakeCmdResult{Stdout: "0", Error: errors.New("errors")})

	_, err := action.Run(drainTypeStatus)
	assert.Error(t, err)
}

func TestRunWithUpdateErrsIfNotGivenNewSpec(t *testing.T) {
	_, _, _, action := buildDrain()
	_, err := action.Run(drainTypeUpdate)
	assert.Error(t, err)
}

func TestRunWithUpdateRunsDrainWithUpdatedPackages(t *testing.T) {
	cmdRunner, fs, _, action := buildDrain()
	currentSpec := boshas.V1ApplySpec{}
	currentSpec.JobSpec.Template = "foo"

	newSpec := boshas.V1ApplySpec{
		PackageSpecs: map[string]boshas.PackageSpec{
			"foo": boshas.PackageSpec{
				Name: "foo",
				Sha1: "foo-sha1-new",
			},
		},
	}

	fs.WriteToFile("/var/vcap/bosh/spec.json", marshalSpecForTests(currentSpec))
	drainScriptPath := filepath.Join("/var/vcap/jobs", currentSpec.JobSpec.Template, "bin", "drain")
	fs.WriteToFile(drainScriptPath, "")
	cmdRunner.AddCmdResult(drainScriptPath+" job_new hash_new foo", fakesys.FakeCmdResult{Stdout: "1"})

	_, err := action.Run(drainTypeUpdate, newSpec)
	assert.NoError(t, err)

	expectedCmd := boshsys.Command{
		Name: "/var/vcap/jobs/foo/bin/drain",
		Args: []string{"job_new", "hash_new", "foo"},
		Env: map[string]string{
			"PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
		},
	}

	assert.Equal(t, []boshsys.Command{expectedCmd}, cmdRunner.RunComplexCommands)
}

func TestRunWithShutdown(t *testing.T) {
	cmdRunner, fs, notifier, action := buildDrain()

	currentSpec := boshas.V1ApplySpec{}
	currentSpec.JobSpec.Template = "foo"
	fs.WriteToFile("/var/vcap/bosh/spec.json", marshalSpecForTests(currentSpec))

	drainScriptPath := filepath.Join("/var/vcap/jobs", currentSpec.JobSpec.Template, "bin", "drain")
	fs.WriteToFile(drainScriptPath, "")
	cmdRunner.AddCmdResult(drainScriptPath+" job_shutdown hash_unchanged", fakesys.FakeCmdResult{Stdout: "1"})

	drainStatus, err := action.Run(drainTypeShutdown)
	assert.NoError(t, err)
	assert.Equal(t, 1, drainStatus)

	expectedCmd := boshsys.Command{
		Name: "/var/vcap/jobs/foo/bin/drain",
		Args: []string{"job_shutdown", "hash_unchanged"},
		Env: map[string]string{
			"PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
		},
	}

	assert.Equal(t, 1, len(cmdRunner.RunComplexCommands))
	assert.Equal(t, expectedCmd, cmdRunner.RunComplexCommands[0])
	assert.True(t, notifier.NotifiedShutdown)
}

func TestRunWithStatus(t *testing.T) {
	cmdRunner, fs, _, action := buildDrain()

	currentSpec := boshas.V1ApplySpec{}
	currentSpec.JobSpec.Template = "foo"
	fs.WriteToFile("/var/vcap/bosh/spec.json", marshalSpecForTests(currentSpec))

	drainScriptPath := filepath.Join("/var/vcap/jobs", currentSpec.JobSpec.Template, "bin", "drain")
	fs.WriteToFile(drainScriptPath, "")
	cmdRunner.AddCmdResult(drainScriptPath+" job_check_status hash_unchanged", fakesys.FakeCmdResult{Stdout: "1"})

	drainStatus, err := action.Run(drainTypeStatus)
	assert.NoError(t, err)
	assert.Equal(t, 1, drainStatus)

	expectedCmd := boshsys.Command{
		Name: "/var/vcap/jobs/foo/bin/drain",
		Args: []string{"job_check_status", "hash_unchanged"},
		Env: map[string]string{
			"PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
		},
	}

	assert.Equal(t, 1, len(cmdRunner.RunComplexCommands))
	assert.Equal(t, expectedCmd, cmdRunner.RunComplexCommands[0])
}

func buildDrain() (
	cmdRunner *fakesys.FakeCmdRunner,
	fs *fakesys.FakeFileSystem,
	notifier *fakenotif.FakeNotifier,
	action drainAction,
) {
	cmdRunner = fakesys.NewFakeCmdRunner()
	fs = fakesys.NewFakeFileSystem()
	notifier = fakenotif.NewFakeNotifier()
	action = newDrain(cmdRunner, fs, notifier)
	return
}

func marshalSpecForTests(spec boshas.V1ApplySpec) (contents string) {
	bytes, _ := json.Marshal(spec)
	contents = string(bytes)
	return
}
