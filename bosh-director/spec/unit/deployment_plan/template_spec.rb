require 'spec_helper'

describe Bosh::Director::DeploymentPlan::Template do
  # Currently this class is tested mostly in DeploymentPlan::ReleaseVersion spec.
  # In the future these tests can be migrated to here.
  describe '#add_link_info' do
    subject(:template) { described_class.new(nil, 'foo') }
    context 'given properly formated arguments' do
      it 'should populate link_infos' do
        template.add_link_info('job_name', 'provides', 'link', {'name'=>'link','type'=>'type'})
        template.add_link_info('job_name', 'provides', 'link', {'from'=>'link'})
        expect(template.link_infos).to eq({"job_name"=>{"provides"=>{"link"=>{"name"=>"link", "type"=>"type", "from"=>"link"}}}})
      end
    end
  end

end
