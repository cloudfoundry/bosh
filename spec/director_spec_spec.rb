require 'spec_helper'

RSpec.describe 'director job spec' do
  let(:spec_yaml) { YAML.load_file(File.join(RELEASE_ROOT, 'jobs/director/spec')) }

  it 'defaults director.trusted_certs to empty string' do
    expect(spec_yaml['properties']['director.trusted_certs']['default']).to eq('')
  end

  it 'defaults director.ignore_missing_gateway to false' do
    expect(spec_yaml['properties']['director.ignore_missing_gateway']['default']).to eq(false)
  end

  it 'defaults director.nginx.enable_metrics_endpoint to false' do
    expect(spec_yaml['properties']['director.nginx.enable_metrics_endpoint']['default']).to eq(false)
  end
end
