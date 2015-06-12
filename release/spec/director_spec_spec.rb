require 'rspec'
require 'yaml'

describe 'director job spec' do

  let(:spec_yaml) { YAML.load_file(File.join(File.dirname(__FILE__), '../jobs/director/spec')) }

  it 'defaults director.trusted_certs to empty string' do
    expect(spec_yaml['properties']['director.trusted_certs']['default']).to eq('')
  end

end
