package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	boshassert "bosh/assert"
	fakejobsuper "bosh/jobsupervisor/fakes"
	boshntp "bosh/platform/ntp"
	fakentp "bosh/platform/ntp/fakes"
	boshvitals "bosh/platform/vitals"
	fakevitals "bosh/platform/vitals/fakes"
	boshsettings "bosh/settings"
	fakesettings "bosh/settings/fakes"
)

func buildGetStateAction(settings boshsettings.Service) (
	specService *fakeas.FakeV1Service,
	jobSupervisor *fakejobsuper.FakeJobSupervisor,
	vitalsService *fakevitals.FakeService,
	action GetStateAction,
) {
	jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
	specService = fakeas.NewFakeV1Service()
	vitalsService = fakevitals.NewFakeService()
	fakeNTPService := &fakentp.FakeService{
		GetOffsetNTPOffset: boshntp.NTPInfo{
			Offset:    "0.34958",
			Timestamp: "12 Oct 17:37:58",
		},
	}
	action = NewGetState(settings, specService, jobSupervisor, vitalsService, fakeNTPService)
	return
}
func init() {
	Describe("GetState", func() {
		It("get state should be synchronous", func() {
			settings := &fakesettings.FakeSettingsService{}
			_, _, _, action := buildGetStateAction(settings)
			Expect(action.IsAsynchronous()).To(BeFalse())
		})

		It("is not persistent", func() {
			settings := &fakesettings.FakeSettingsService{}
			_, _, _, action := buildGetStateAction(settings)
			Expect(action.IsPersistent()).To(BeFalse())
		})

		Describe("Run", func() {
			It("returns state", func() {
				settings := &fakesettings.FakeSettingsService{}
				settings.AgentId = "my-agent-id"
				settings.Vm.Name = "vm-abc-def"

				specService, jobSupervisor, _, action := buildGetStateAction(settings)
				jobSupervisor.StatusStatus = "running"

				specService.Spec = boshas.V1ApplySpec{
					Deployment: "fake-deployment",
				}

				expectedSpec := GetStateV1ApplySpec{
					AgentId:      "my-agent-id",
					JobState:     "running",
					BoshProtocol: "1",
					Vm:           boshsettings.Vm{Name: "vm-abc-def"},
					Ntp: boshntp.NTPInfo{
						Offset:    "0.34958",
						Timestamp: "12 Oct 17:37:58",
					},
				}
				expectedSpec.Deployment = "fake-deployment"

				state, err := action.Run()
				Expect(err).ToNot(HaveOccurred())

				Expect(state.AgentId).To(Equal(expectedSpec.AgentId))
				Expect(state.JobState).To(Equal(expectedSpec.JobState))
				Expect(state.Deployment).To(Equal(expectedSpec.Deployment))
				boshassert.LacksJsonKey(GinkgoT(), state, "vitals")

				Expect(state).To(Equal(expectedSpec))
			})

			It("returns state in full format", func() {
				settings := &fakesettings.FakeSettingsService{}
				settings.AgentId = "my-agent-id"
				settings.Vm.Name = "vm-abc-def"

				specService, jobSupervisor, fakeVitals, action := buildGetStateAction(settings)
				jobSupervisor.StatusStatus = "running"

				specService.Spec = boshas.V1ApplySpec{
					Deployment: "fake-deployment",
				}

				expectedVitals := boshvitals.Vitals{
					Load: []string{"foo", "bar", "baz"},
				}
				fakeVitals.GetVitals = expectedVitals
				expectedVm := map[string]interface{}{"name": "vm-abc-def"}

				state, err := action.Run("full")
				Expect(err).ToNot(HaveOccurred())

				boshassert.MatchesJsonString(GinkgoT(), state.AgentId, `"my-agent-id"`)
				boshassert.MatchesJsonString(GinkgoT(), state.JobState, `"running"`)
				boshassert.MatchesJsonString(GinkgoT(), state.Deployment, `"fake-deployment"`)
				Expect(*state.Vitals).To(Equal(expectedVitals))
				boshassert.MatchesJsonMap(GinkgoT(), state.Vm, expectedVm)
			})

			Context("when current cannot be retrieved", func() {

				It("without current spec", func() {
					settings := &fakesettings.FakeSettingsService{}
					specService, _, _, action := buildGetStateAction(settings)

					specService.GetErr = errors.New("fake-spec-get-error")

					_, err := action.Run()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-spec-get-error"))
				})
			})

			Context("when vitals cannot be retrieved", func() {
				It("returns error", func() {
					settings := &fakesettings.FakeSettingsService{}
					_, _, fakeVitals, action := buildGetStateAction(settings)

					fakeVitals.GetErr = errors.New("fake-vitals-get-error")

					_, err := action.Run("full")
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-vitals-get-error"))
				})
			})

		})

	})
}
