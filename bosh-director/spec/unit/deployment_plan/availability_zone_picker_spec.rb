require 'spec_helper'

describe Bosh::Director::DeploymentPlan::AvailabilityZonePicker do
  subject(:zone_picker) {  Bosh::Director::DeploymentPlan::AvailabilityZonePicker.new }
  let(:az1) { Bosh::Director::DeploymentPlan::AvailabilityZone.new({'name' => '1'}) }
  let(:az2) { Bosh::Director::DeploymentPlan::AvailabilityZone.new({'name' => '2'}) }
  let(:az3) { Bosh::Director::DeploymentPlan::AvailabilityZone.new({'name' => '3'}) }

  def desired_instance
    Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, nil, nil)
  end

  describe "placing and matching" do
    it 'a job in no zones with 3 instances, we expect' do
      unmatched_desired_instances = [desired_instance, desired_instance, desired_instance]
      existing_0 = instance_double(Bosh::Director::Models::Instance, availability_zone: nil)
      existing_1 = instance_double(Bosh::Director::Models::Instance, availability_zone: nil)
      unmatched_existing_instanaces = [existing_0, existing_1]

      azs = []
      results = zone_picker.place_and_match_instances(azs, unmatched_desired_instances, unmatched_existing_instanaces)

      expect(results[:desired]).to match_array([
            Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, nil, existing_0),
            Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, nil, existing_1),
            Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, nil, nil)])
      expect(results[:obsolete]).to eq([])
    end

    it "a job in 2 zones with 3 instances, we expect" do
      unmatched_desired_instances = [desired_instance, desired_instance, desired_instance]
      unmatched_existing_instanaces = []

      azs = [az1, az2]
      results = zone_picker.place_and_match_instances(azs, unmatched_desired_instances, unmatched_existing_instanaces)

      expect(results[:desired]).to match_array([
            Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, az1, nil),
            Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, az1, nil),
            Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, az2, nil)])
      expect(results[:obsolete]).to eq([])
    end

    describe "when a job is deployed in 2 zones with 3 existing instances, and re-deployed into one zone" do
      it "should match the 2 existing instances from the desired zone to 2 of the desired instances" do
        unmatched_desired_instances = [desired_instance, desired_instance, desired_instance]

        existing_zone1_0 = instance_double(Bosh::Director::Models::Instance, availability_zone: "1")
        existing_zone1_1 = instance_double(Bosh::Director::Models::Instance, availability_zone: "1")
        existing_zone2_0 = instance_double(Bosh::Director::Models::Instance, availability_zone: "2")
        unmatched_existing_instances = [existing_zone1_0, existing_zone1_1, existing_zone2_0]

        azs = [az1]
        results = zone_picker.place_and_match_instances(azs, unmatched_desired_instances, unmatched_existing_instances)

        expect(results[:desired]).to match_array([
              Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, az1, existing_zone1_0),
              Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, az1, existing_zone1_1),
              Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, az1, nil)])

        expect(results[:obsolete]).to match_array([existing_zone2_0])
      end
    end

    describe "when a job is deployed in 2 zones with 5 existing instances, and re-deployed into 3 zones" do
      it "should match the 2 existing instances from the 2 desired zones" do
        unmatched_desired_instances = [
          desired_instance,
          desired_instance,
          desired_instance,
          desired_instance,
          desired_instance,
        ]

        existing_zone1_0 = instance_double(Bosh::Director::Models::Instance, availability_zone: "1")
        existing_zone1_1 = instance_double(Bosh::Director::Models::Instance, availability_zone: "1")
        existing_zone1_2 = instance_double(Bosh::Director::Models::Instance, availability_zone: "1")
        existing_zone2_0 = instance_double(Bosh::Director::Models::Instance, availability_zone: "2")
        existing_zone2_1 = instance_double(Bosh::Director::Models::Instance, availability_zone: "2")

        unmatched_existing_instances = [existing_zone1_0, existing_zone1_1, existing_zone1_2, existing_zone2_0, existing_zone2_1]

        azs = [az1, az2, az3]
        results = zone_picker.place_and_match_instances(azs, unmatched_desired_instances, unmatched_existing_instances)

        expect(results[:desired]).to match_array([
              Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, az1, existing_zone1_0),
              Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, az1, existing_zone1_1),
              Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, az2, existing_zone2_0),
              Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, az2, existing_zone2_1),
              Bosh::Director::DeploymentPlan::DesiredInstance.new(nil, nil, nil, az3, nil)])

        expect(results[:obsolete]).to match_array([existing_zone1_2])
      end
    end
  end
end

