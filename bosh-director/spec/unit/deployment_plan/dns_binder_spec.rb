require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::DnsBinder do
    subject { described_class.new(deployment) }
    let (:deployment) { instance_double('Bosh::Director::DeploymentPlan::Planner') }

    describe '#bind_deployment' do
      context 'when dns is enabled' do
        before { allow(Config).to receive(:dns_enabled?).and_return(true) }

        before do
          allow(Config).to receive(:dns).and_return({ 'address' => '1.2.3.4' })
          allow(Config).to receive(:dns_domain_name).and_return('bosh')
        end

        it "should create the domain if it doesn't exist" do
          domain = nil
          expect(deployment).to receive(:dns_domain=) { |*args| domain = args.first }
          subject.bind_deployment

          expect(Models::Dns::Domain.count).to eq(1)
          expect(Models::Dns::Domain.first).to eq(domain)
          expect(domain.name).to eq('bosh')
          expect(domain.type).to eq('NATIVE')
        end

        it 'should reuse the domain if it exists' do
          domain = Models::Dns::Domain.make(:name => 'bosh', :type => 'NATIVE')
          expect(deployment).to receive(:dns_domain=).with(domain)
          subject.bind_deployment

          expect(Models::Dns::Domain.count).to eq(1)
        end

        it "should create the SOA, NS & A record if they doesn't exist" do
          domain = Models::Dns::Domain.make(:name => 'bosh', :type => 'NATIVE')
          expect(deployment).to receive(:dns_domain=)
          subject.bind_deployment

          expect(Models::Dns::Record.count).to eq(3)
          records = Models::Dns::Record
          types = records.map { |r| r.type }
          expect(types).to eq(%w[SOA NS A])
        end

        it 'should reuse the SOA record if it exists' do
          domain = Models::Dns::Domain.make(:name => 'bosh', :type => 'NATIVE')
          soa = Models::Dns::Record.make(:domain => domain, :name => 'bosh',
            :type => 'SOA')
          ns = Models::Dns::Record.make(:domain => domain, :name => 'bosh',
            :type => 'NS', :content => 'ns.bosh',
            :ttl => 14400) # 4h
          a = Models::Dns::Record.make(:domain => domain, :name => 'ns.bosh',
            :type => 'A', :content => '1.2.3.4',
            :ttl => 14400) # 4h
          expect(deployment).to receive(:dns_domain=)
          subject.bind_deployment

          soa.refresh
          ns.refresh
          a.refresh

          expect(Models::Dns::Record.count).to eq(3)
          expect(Models::Dns::Record.all).to eq([soa, ns, a])
        end
      end

      context 'when dns is not enabled' do
        before { allow(Config).to receive(:dns_enabled?).and_return(false) }

        it 'does not create any new dns domains' do
          expect {
            subject.bind_deployment
          }.to_not change { Models::Dns::Domain.count }
        end

        it 'does not create any new dns records' do
          expect {
            subject.bind_deployment
          }.to_not change { Models::Dns::Record.count }
        end
      end
    end
  end
end
