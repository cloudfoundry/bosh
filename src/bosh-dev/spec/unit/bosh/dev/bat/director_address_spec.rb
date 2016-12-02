require 'spec_helper'
require 'bosh/dev/bat/director_address'

module Bosh::Dev::Bat
  describe DirectorAddress do
    describe '.from_env' do
      it 'fetches address from env' do
        address = described_class.from_env({ 'env-key' => 'ip-from-env' }, 'env-key')
        expect(address.hostname).to eq 'ip-from-env'
        expect(address.ip).to eq 'ip-from-env'
      end
    end

    describe '.resolved_from_env' do
      it 'fetches address from env and resolves it via DNS' do
        expect(Resolv)
          .to receive(:getaddress)
          .with('micro.subdomain-from-env.cf-app.com')
          .and_return('resolved-ip')

        address = described_class.resolved_from_env(
          { 'env-key' => 'subdomain-from-env' }, 'env-key')
        expect(address.hostname).to eq 'micro.subdomain-from-env.cf-app.com'
        expect(address.ip).to eq 'resolved-ip'
      end
    end

    describe '#initialize' do
      it 'sets hostname and ip' do
        subject = described_class.new('hostname', 'ip')
        expect(subject.hostname).to eq 'hostname'
        expect(subject.ip).to eq 'ip'
      end
    end
  end
end
