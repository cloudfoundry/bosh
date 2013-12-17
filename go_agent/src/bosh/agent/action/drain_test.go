package action

import (
	boshas "bosh/agent/applier/applyspec"
	fakenotif "bosh/notification/fakes"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestDrainShouldBeAsynchronous(t *testing.T) {
	_, _, _, action := buildDrain()
	assert.True(t, action.IsAsynchronous())
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

func TestUpdatePackages(t *testing.T) {
	oldPkgs := map[string]boshas.PackageSpec{
		"foo": boshas.PackageSpec{
			Name: "foo",
			Sha1: "foo-sha1-old",
		},
		"bar": boshas.PackageSpec{
			Name: "bar",
			Sha1: "bar-sha1",
		},
	}
	newPkgs := map[string]boshas.PackageSpec{
		"foo": boshas.PackageSpec{
			Name: "foo",
			Sha1: "foo-sha1-new",
		},
		"bar": boshas.PackageSpec{
			Name: "bar",
			Sha1: "bar-sha1",
		},
		"baz": boshas.PackageSpec{
			Name: "baz",
			Sha1: "baz-sha1",
		},
	}
	updatedPkgs := updatedPackages(oldPkgs, newPkgs)
	assert.Equal(t, []string{"foo", "baz"}, updatedPkgs)
}

func TestRunWithShutdown(t *testing.T) {
	cmdRunner, fs, notifier, action := buildDrain()

	currentSpec := boshas.V1ApplySpec{}
	currentSpec.JobSpec.Template = "foo"
	fs.WriteToFile("/var/vcap/bosh/spec.json", marshalSpecForTests(currentSpec))

	drainStatus, err := action.Run(drainTypeShutdown)
	assert.NoError(t, err)
	assert.Equal(t, 0, drainStatus)

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
