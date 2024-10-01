require_relative '../spec_helper'
require 'net/http'

describe 'the jobs api', type: :integration do
  with_reset_sandbox_before_each
  let(:stemcell_filename) { asset_path('valid_stemcell.tgz') }
  let(:release_path) { asset_path('compiled_releases/test_release/releases/test_release/test_release-1.tgz') }
  let(:cloud_config_manifest) { yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config) }

  before do
    bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
    bosh_runner.run("upload-stemcell #{stemcell_filename}")
  end

  it 'shows the full spec of the job' do
    deployment_manifest = yaml_file(
      'deployment_manifest',
      Bosh::Spec::Deployments.local_release_manifest('file://' + release_path, 1),
    )

    output = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'minimal')
    expect(output).to match(/Using deployment 'minimal'/)
    expect(output).to match(/Release has been created: test_release\/1/)
    expect(output).to match(/Succeeded/)

    http = Net::HTTP.new('127.0.0.1', current_sandbox.director_port)

    http.ca_file = current_sandbox.certificate_path
    http.use_ssl = true

    uri = URI(current_sandbox.director_url + '/jobs')
    uri.query = URI.encode_www_form(
      name: 'job_using_pkg_3',
      release_name: 'test_release',
      fingerprint: '54120dd68fab145433df83262a9ba9f3de527a4b'
    )

    req = Net::HTTP::Get.new(uri)
    req.basic_auth 'test', 'test'

    response = http.request(req)
    expect(response.code).to eq '200'

    body = JSON.parse(response.body)
    expect(body.length).to eq 1
    expect(body[0]).to eq(
      { "fingerprint" => "54120dd68fab145433df83262a9ba9f3de527a4b",
        "name" => "job_using_pkg_3",
        "spec"=>
        {"name"=>"job_using_pkg_3",
         "templates"=>{},
         "packages"=>["pkg_3_depends_on_2"],
         "configuration"=>{"file1.conf"=>"config/file1.conf"}}}
    )
  end
end
