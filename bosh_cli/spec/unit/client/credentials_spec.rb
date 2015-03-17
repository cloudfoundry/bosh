require 'spec_helper'

describe Bosh::Cli::Client::UaaCredentials do
  subject(:credentials) { described_class.new('fake-token') }
  its(:authorization_header) { is_expected.to eq('bearer fake-token') }
end

describe Bosh::Cli::Client::BasicCredentials do
  subject(:credentials) { described_class.new('fake-user', 'fake-pass') }
  its(:authorization_header) { is_expected.to eq('Basic ZmFrZS11c2VyOmZha2UtcGFzcw==') }
end
