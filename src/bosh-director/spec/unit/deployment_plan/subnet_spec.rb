shared_examples_for 'a subnet' do
  describe '.parse_availability_zones' do
    let(:name) { 'network' }

    let(:azs) do
      [
        Bosh::Director::DeploymentPlan::AvailabilityZone.new('z1', {}),
        Bosh::Director::DeploymentPlan::AvailabilityZone.new('z2', {}),
      ]
    end

    context 'when the subnet defines both az and azs properties' do
      let(:subnet_spec) do
        {
          'azs' => %w[z1 z2],
          'az' => 'z1',
        }
      end

      it 'errors' do
        expect do
          described_class.parse_availability_zones(subnet_spec, name, azs)
        end.to raise_error(
          Bosh::Director::NetworkInvalidProperty,
          "Network 'network' contains both 'az' and 'azs'. Choose one.",
        )
      end
    end

    context 'when the subnet defines the azs property' do
      context 'with valid azs' do
        let(:subnet_spec) do
          {
            'azs' => %w[z1 z2],
          }
        end

        it 'should return the zones' do
          names = described_class.parse_availability_zones(subnet_spec, name, azs)
          expect(names).to eq(%w[z1 z2])
        end
      end

      context 'subnet azs are empty' do
        let(:subnet_spec) do
          {
            'azs' => [],
          }
        end

        it 'errors' do
          expect do
            described_class.parse_availability_zones(subnet_spec, name, azs)
          end.to raise_error(Bosh::Director::NetworkInvalidProperty, "Network 'network' refers to an empty 'azs' array")
        end
      end

      context 'one of the subnet azs dont exist' do
        let(:subnet_spec) do
          {
            'azs' => %w[z1 bar z2],
          }
        end

        it 'errors' do
          expect do
            described_class.parse_availability_zones(subnet_spec, name, azs)
          end.to raise_error(
            Bosh::Director::NetworkSubnetUnknownAvailabilityZone,
            "Network 'network' refers to an unknown availability zone 'bar'",
          )
        end
      end
    end

    context 'when the subnet defines az property' do
      context 'with a valid az' do
        let(:subnet_spec) do
          {
            'az' => 'z1',
          }
        end

        it 'should return the zones' do
          names = described_class.parse_availability_zones(subnet_spec, name, azs)
          expect(names).to eq(%w[z1])
        end
      end

      context 'with no availability zone specified' do
        let(:subnet_spec) do
          {}
        end

        it 'does not care whether that az name is in the list' do
          expect do
            described_class.parse_availability_zones(subnet_spec, name, azs)
          end.to_not raise_error
        end
      end

      context 'with a nil availability zone' do
        let(:subnet_spec) do
          { 'az' => nil }
        end

        it 'errors' do
          expect do
            described_class.parse_availability_zones(subnet_spec, name, azs)
          end.to raise_error(Bosh::Director::ValidationInvalidType)
        end
      end

      context 'with an availability zone that is not present' do
        let(:subnet_spec) do
          { 'az' => 'foo' }
        end

        it 'errors' do
          expect do
            described_class.parse_availability_zones(subnet_spec, name, azs)
          end.to raise_error(
            Bosh::Director::NetworkSubnetUnknownAvailabilityZone,
            "Network 'network' refers to an unknown availability zone 'foo'",
          )
        end
      end
    end
  end
end
