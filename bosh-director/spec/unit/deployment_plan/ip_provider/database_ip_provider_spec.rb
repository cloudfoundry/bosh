require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe DatabaseIpProvider do
    subject(:ip_provider) do
      DatabaseIpProvider.new(
        range,
        'fake-network',
        restricted_ips,
        static_ips,
        logger
      )
    end
    let(:deployment_model) { Bosh::Director::Models::Deployment.make }
    let(:restricted_ips) { Set.new }
    let(:static_ips) { Set.new }
    let(:range) { NetAddr::CIDR.create('192.168.0.1/24') }
    let(:instance) do
      instance_double(Instance, model: Bosh::Director::Models::Instance.make, to_s: 'fake-job/0')
    end
    let(:network) { instance_double(ManualNetwork, name: 'fake-network') }

    before do
      Bosh::Director::Config.current_job = Bosh::Director::Jobs::BaseJob.new
      Bosh::Director::Config.current_job.task_id = 'fake-task-id'
    end

    def cidr_ip(ip)
      NetAddr::CIDR.create(ip).to_i
    end

    def create_reservation(ip)
      BD::StaticNetworkReservation.new(instance, network, cidr_ip(ip))
    end

    def reserve_ip(ip)
      Bosh::Director::Models::IpAddress.new(
        address: cidr_ip(ip),
        network_name: 'fake-network',
        instance: instance.model,
        task_id: Bosh::Director::Config.current_job.task_id
      ).save
    end

    describe 'allocate_dynamic_ip' do
      context 'when there are no IPs reserved for that network' do
        it 'returns the first in the range' do
          ip_address = ip_provider.allocate_dynamic_ip(instance)

          expected_ip_address = cidr_ip('192.168.0.0')
          expect(ip_address).to eq(expected_ip_address)
        end
      end

      it 'reserves IP as dynamic' do
        ip_provider.allocate_dynamic_ip(instance)
        saved_address = Bosh::Director::Models::IpAddress.first
        expect(saved_address.static).to eq(false)
      end

      context 'when reserving more than one ip' do
        it 'should the next available address' do
          first = ip_provider.allocate_dynamic_ip(instance)
          second = ip_provider.allocate_dynamic_ip(instance)
          expect(first).to eq(cidr_ip('192.168.0.0'))
          expect(second).to eq(cidr_ip('192.168.0.1'))
        end
      end

      context 'when there are restricted ips' do
        let(:restricted_ips) do
          Set.new [
              cidr_ip('192.168.0.0'),
              cidr_ip('192.168.0.1'),
              cidr_ip('192.168.0.3')
            ]
        end

        it 'does not reserve them' do
          expect(ip_provider.allocate_dynamic_ip(instance)).to eq(cidr_ip('192.168.0.2'))
          expect(ip_provider.allocate_dynamic_ip(instance)).to eq(cidr_ip('192.168.0.4'))
        end
      end

      context 'when there are static and restricted ips' do
        let(:restricted_ips) do
          Set.new [
              cidr_ip('192.168.0.0'),
              cidr_ip('192.168.0.3')
            ]
        end

        let(:static_ips) do
          Set.new [
              cidr_ip('192.168.0.1'),
            ]
        end

        it 'does not reserve them' do
          expect(ip_provider.allocate_dynamic_ip(instance)).to eq(cidr_ip('192.168.0.2'))
          expect(ip_provider.allocate_dynamic_ip(instance)).to eq(cidr_ip('192.168.0.4'))
        end
      end

      context 'when there are available IPs between reserved IPs' do
        let(:static_ips) do
          Set.new [
              cidr_ip('192.168.0.0'),
              cidr_ip('192.168.0.1'),
              cidr_ip('192.168.0.3'),
            ]
        end

        before do
          ['192.168.0.0', '192.168.0.1', '192.168.0.3'].each { |ip| reserve_ip(ip) }
        end

        it 'returns first non-reserved IP' do
          ip_address = ip_provider.allocate_dynamic_ip(instance)

          expected_ip_address = cidr_ip('192.168.0.2')
          expect(ip_address).to eq(expected_ip_address)
        end
      end

      context 'when range is greater than max reserved IP' do
        let(:range) { NetAddr::CIDR.create('192.168.2.0/24') }

        let(:static_ips) do
          Set.new [
            cidr_ip('192.168.1.1'),
          ]
        end

        before do
          reserve_ip('192.168.1.1')
        end

        it 'uses first IP from range' do
          ip_address = ip_provider.allocate_dynamic_ip(instance)

          expected_ip_address = cidr_ip('192.168.2.0')
          expect(ip_address).to eq(expected_ip_address)
        end
      end

      context 'when all IPs are reserved without holes' do
        let(:static_ips) do
          Set.new [
              cidr_ip('192.168.0.0'),
              cidr_ip('192.168.0.1'),
              cidr_ip('192.168.0.2'),
            ]
        end

        before do
          reserve_ip('192.168.0.0')
          reserve_ip('192.168.0.1')
          reserve_ip('192.168.0.2')
        end

        it 'returns IP next after reserved' do
          ip_address = ip_provider.allocate_dynamic_ip(instance)

          expected_ip_address = cidr_ip('192.168.0.3')
          expect(ip_address).to eq(expected_ip_address)
        end
      end

      context 'when all IPs in the range are taken' do
        let(:range) { NetAddr::CIDR.create('192.168.0.0/32') }

        it 'returns nil' do
          expect(ip_provider.allocate_dynamic_ip(instance)).to_not be_nil
          expect(ip_provider.allocate_dynamic_ip(instance)).to be_nil
        end
      end

      context 'when reserving IP fails' do
        let(:range) { NetAddr::CIDR.create('192.168.0.0/30') }

        def fail_saving_ips(ips, fail_error)
          original_saves = {}
          ips.each do |ip|
            ip_address = Bosh::Director::Models::IpAddress.new(
              address: ip,
              network_name: 'fake-network',
              instance: instance.model,
              task_id: Bosh::Director::Config.current_job.task_id
            )
            original_save = ip_address.method(:save)
            original_saves[ip] = original_save
          end

          allow_any_instance_of(Bosh::Director::Models::IpAddress).to receive(:save) do |model|
            if ips.include?(model.address)
              original_save = original_saves[model.address]
              original_save.call
              raise fail_error
            end
            model
          end
        end

        shared_examples :retries_on_race_condition do
          context 'when allocating some IPs fails' do
            before do
              fail_saving_ips([
                  cidr_ip('192.168.0.0'),
                  cidr_ip('192.168.0.1'),
                  cidr_ip('192.168.0.2'),
                ],
                fail_error
              )
            end

            it 'retries until it succeeds' do
              expect(ip_provider.allocate_dynamic_ip(instance)).to eq(cidr_ip('192.168.0.3'))
            end
          end

          context 'when allocating any IP fails' do
            before do
              fail_saving_ips([
                  cidr_ip('192.168.0.0'),
                  cidr_ip('192.168.0.1'),
                  cidr_ip('192.168.0.2'),
                  cidr_ip('192.168.0.3'),
                ],
                fail_error
              )
            end

            it 'retries until there are no more IPs available' do
              expect(ip_provider.allocate_dynamic_ip(instance)).to be_nil
            end
          end
        end

        context 'when sequel validation errors' do
          let(:fail_error) { Sequel::ValidationFailed.new('address and network are not unique') }

          it_behaves_like :retries_on_race_condition
        end

        context 'when postgres unique errors' do
          let(:fail_error) { Sequel::DatabaseError.new('duplicate key value violates unique constraint') }

          it_behaves_like :retries_on_race_condition
        end

        context 'when mysql unique errors' do
          let(:fail_error) { Sequel::DatabaseError.new('Duplicate entry') }

          it_behaves_like :retries_on_race_condition
        end
      end
    end
  end
end
