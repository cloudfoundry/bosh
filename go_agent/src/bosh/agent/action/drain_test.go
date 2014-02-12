package action_test

import (
	. "bosh/agent/action"
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakedrain "bosh/agent/drain/fakes"
	fakenotif "bosh/notification/fakes"
	"errors"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func buildDrain() (
	notifier *fakenotif.FakeNotifier,
	fakeDrainProvider *fakedrain.FakeDrainScriptProvider,
	action DrainAction,
) {
	notifier = fakenotif.NewFakeNotifier()

	specService := fakeas.NewFakeV1Service()
	currentSpec := boshas.V1ApplySpec{}
	currentSpec.JobSpec.Template = "foo"
	specService.Spec = currentSpec

	fakeDrainProvider = fakedrain.NewFakeDrainScriptProvider()
	fakeDrainProvider.NewDrainScriptDrainScript.ExistsBool = true

	action = NewDrain(notifier, specService, fakeDrainProvider)

	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("drain should be asynchronous", func() {
			_, _, action := buildDrain()
			assert.True(GinkgoT(), action.IsAsynchronous())
		})
		It("drain run update skips drain script when without drain script", func() {

			_, fakeDrainProvider, action := buildDrain()

			newSpec := boshas.V1ApplySpec{
				PackageSpecs: map[string]boshas.PackageSpec{
					"foo": boshas.PackageSpec{
						Name: "foo",
						Sha1: "foo-sha1-new",
					},
				},
			}

			fakeDrainProvider.NewDrainScriptDrainScript.ExistsBool = false

			_, err := action.Run(DrainTypeUpdate, newSpec)
			assert.NoError(GinkgoT(), err)
			assert.False(GinkgoT(), fakeDrainProvider.NewDrainScriptDrainScript.DidRun)
		})
		It("drain run shutdown skips drain script when without drain script", func() {

			_, fakeDrainProvider, action := buildDrain()

			newSpec := boshas.V1ApplySpec{
				PackageSpecs: map[string]boshas.PackageSpec{
					"foo": boshas.PackageSpec{
						Name: "foo",
						Sha1: "foo-sha1-new",
					},
				},
			}

			fakeDrainProvider.NewDrainScriptDrainScript.ExistsBool = false

			_, err := action.Run(DrainTypeShutdown, newSpec)
			assert.NoError(GinkgoT(), err)
			assert.False(GinkgoT(), fakeDrainProvider.NewDrainScriptDrainScript.DidRun)
		})
		It("drain run status errs when without drain script", func() {

			_, fakeDrainProvider, action := buildDrain()

			fakeDrainProvider.NewDrainScriptDrainScript.ExistsBool = false

			_, err := action.Run(DrainTypeStatus)
			assert.Error(GinkgoT(), err)
		})
		It("drain errs when drain script exits with error", func() {

			_, fakeDrainScriptProvider, action := buildDrain()

			fakeDrainScriptProvider.NewDrainScriptDrainScript.RunExitStatus = 0
			fakeDrainScriptProvider.NewDrainScriptDrainScript.RunError = errors.New("Fake error")

			value, err := action.Run(DrainTypeStatus)
			assert.Equal(GinkgoT(), value, 0)
			assert.Error(GinkgoT(), err)
		})
		It("run with update errs if not given new spec", func() {

			_, _, action := buildDrain()
			_, err := action.Run(DrainTypeUpdate)
			assert.Error(GinkgoT(), err)
		})
		It("run with update runs drain with updated packages", func() {

			_, fakeDrainScriptProvider, action := buildDrain()

			newSpec := boshas.V1ApplySpec{
				PackageSpecs: map[string]boshas.PackageSpec{
					"foo": boshas.PackageSpec{
						Name: "foo",
						Sha1: "foo-sha1-new",
					},
				},
			}

			drainStatus, err := action.Run(DrainTypeUpdate, newSpec)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), 1, drainStatus)
			assert.Equal(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptTemplateName, "foo")
			assert.True(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptDrainScript.DidRun)
			assert.Equal(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.JobChange(), "job_new")
			assert.Equal(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.HashChange(), "hash_new")
			assert.Equal(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.UpdatedPackages(), []string{"foo"})
		})
		It("run with shutdown", func() {

			fakeNotifier, fakeDrainScriptProvider, action := buildDrain()

			drainStatus, err := action.Run(DrainTypeShutdown)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), 1, drainStatus)
			assert.Equal(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptTemplateName, "foo")
			assert.True(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptDrainScript.DidRun)
			assert.Equal(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.JobChange(), "job_shutdown")
			assert.Equal(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.HashChange(), "hash_unchanged")
			assert.Equal(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.UpdatedPackages(), []string{})
			assert.True(GinkgoT(), fakeNotifier.NotifiedShutdown)
		})
		It("run with status", func() {

			_, fakeDrainScriptProvider, action := buildDrain()

			drainStatus, err := action.Run(DrainTypeStatus)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), 1, drainStatus)
			assert.Equal(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptTemplateName, "foo")
			assert.True(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptDrainScript.DidRun)
			assert.Equal(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.JobChange(), "job_check_status")
			assert.Equal(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.HashChange(), "hash_unchanged")
			assert.Equal(GinkgoT(), fakeDrainScriptProvider.NewDrainScriptDrainScript.RunParams.UpdatedPackages(), []string{})
		})
	})
}
