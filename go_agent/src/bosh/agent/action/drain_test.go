package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	. "bosh/agent/action"
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakedrain "bosh/agent/drain/fakes"
	fakenotif "bosh/notification/fakes"
)

func init() {
	Describe("DrainAction", func() {
		var (
			notifier            *fakenotif.FakeNotifier
			specService         *fakeas.FakeV1Service
			drainScriptProvider *fakedrain.FakeDrainScriptProvider
			action              DrainAction
		)

		BeforeEach(func() {
			notifier = fakenotif.NewFakeNotifier()

			specService = fakeas.NewFakeV1Service()
			currentSpec := boshas.V1ApplySpec{}
			currentSpec.JobSpec.Template = "foo"
			specService.Spec = currentSpec

			drainScriptProvider = fakedrain.NewFakeDrainScriptProvider()
			drainScriptProvider.NewDrainScriptDrainScript.ExistsBool = true

			action = NewDrain(notifier, specService, drainScriptProvider)
		})

		It("drain should be asynchronous", func() {
			assert.True(GinkgoT(), action.IsAsynchronous())
		})

		It("is not persistent", func() {
			assert.False(GinkgoT(), action.IsPersistent())
		})

		Context("when current agent spec does not have a template", func() {
			BeforeEach(func() {
				specService.Spec = boshas.V1ApplySpec{}
			})

			Context("when drain update is requested", func() {
				It("return 0 and does not run drain script", func() {
					newSpec := boshas.V1ApplySpec{
						PackageSpecs: map[string]boshas.PackageSpec{
							"foo": boshas.PackageSpec{
								Name: "foo",
								Sha1: "foo-sha1-new",
							},
						},
					}

					value, err := action.Run(DrainTypeUpdate, newSpec)
					Expect(err).ToNot(HaveOccurred())
					Expect(value).To(Equal(0))

					assert.False(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.DidRun)
				})
			})

			Context("when drain shutdown is requested", func() {
				It("returns 0 and does not run drain script", func() {
					newSpec := boshas.V1ApplySpec{
						PackageSpecs: map[string]boshas.PackageSpec{
							"foo": boshas.PackageSpec{
								Name: "foo",
								Sha1: "foo-sha1-new",
							},
						},
					}

					value, err := action.Run(DrainTypeUpdate, newSpec)
					Expect(err).ToNot(HaveOccurred())
					Expect(value).To(Equal(0))

					assert.False(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.DidRun)
				})
			})

			Context("when drain status is requested", func() {
				It("returns error because drain status should only be called after starting draining", func() {
					value, err := action.Run(DrainTypeStatus)
					Expect(err).To(HaveOccurred())
					Expect(value).To(Equal(0))
				})
			})
		})

		Context("when job template does not include drain script", func() {
			BeforeEach(func() {
				drainScriptProvider.NewDrainScriptDrainScript.ExistsBool = false
			})

			Context("when drain update is requested", func() {
				It("returns 0 and does not run drain script", func() {
					newSpec := boshas.V1ApplySpec{
						PackageSpecs: map[string]boshas.PackageSpec{
							"foo": boshas.PackageSpec{
								Name: "foo",
								Sha1: "foo-sha1-new",
							},
						},
					}

					value, err := action.Run(DrainTypeUpdate, newSpec)
					Expect(err).ToNot(HaveOccurred())
					Expect(value).To(Equal(0))

					assert.False(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.DidRun)
				})
			})

			Context("when drain shutdown is requested", func() {
				It("returns 0 and does not run drain script", func() {
					newSpec := boshas.V1ApplySpec{
						PackageSpecs: map[string]boshas.PackageSpec{
							"foo": boshas.PackageSpec{
								Name: "foo",
								Sha1: "foo-sha1-new",
							},
						},
					}

					value, err := action.Run(DrainTypeShutdown, newSpec)
					Expect(err).ToNot(HaveOccurred())
					Expect(value).To(Equal(0))

					assert.False(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.DidRun)
				})
			})

			Context("when drain status is requested", func() {
				It("returns error because drain status should only be called after starting draining", func() {
					value, err := action.Run(DrainTypeStatus)
					Expect(err).To(HaveOccurred())
					Expect(value).To(Equal(0))
				})
			})
		})

		It("drain errs when drain script exits with error", func() {
			drainScriptProvider.NewDrainScriptDrainScript.RunExitStatus = 0
			drainScriptProvider.NewDrainScriptDrainScript.RunError = errors.New("Fake error")

			value, err := action.Run(DrainTypeStatus)
			assert.Equal(GinkgoT(), value, 0)
			assert.Error(GinkgoT(), err)
		})

		It("run with update errs if not given new spec", func() {
			_, err := action.Run(DrainTypeUpdate)
			assert.Error(GinkgoT(), err)
		})

		It("run with update runs drain with updated packages", func() {
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
			assert.Equal(GinkgoT(), drainScriptProvider.NewDrainScriptTemplateName, "foo")
			assert.True(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.DidRun)
			assert.Equal(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.RunParams.JobChange(), "job_new")
			assert.Equal(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.RunParams.HashChange(), "hash_new")
			assert.Equal(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.RunParams.UpdatedPackages(), []string{"foo"})
		})

		It("run with shutdown", func() {
			drainStatus, err := action.Run(DrainTypeShutdown)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), 1, drainStatus)
			assert.Equal(GinkgoT(), drainScriptProvider.NewDrainScriptTemplateName, "foo")
			assert.True(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.DidRun)
			assert.Equal(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.RunParams.JobChange(), "job_shutdown")
			assert.Equal(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.RunParams.HashChange(), "hash_unchanged")
			assert.Equal(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.RunParams.UpdatedPackages(), []string{})
			assert.True(GinkgoT(), notifier.NotifiedShutdown)
		})

		It("run with status", func() {
			drainStatus, err := action.Run(DrainTypeStatus)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), 1, drainStatus)
			assert.Equal(GinkgoT(), drainScriptProvider.NewDrainScriptTemplateName, "foo")
			assert.True(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.DidRun)
			assert.Equal(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.RunParams.JobChange(), "job_check_status")
			assert.Equal(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.RunParams.HashChange(), "hash_unchanged")
			assert.Equal(GinkgoT(), drainScriptProvider.NewDrainScriptDrainScript.RunParams.UpdatedPackages(), []string{})
		})
	})
}
