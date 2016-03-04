require 'spec_helper'

describe Bosh::Director::DeploymentPlan::Template do
  # Currently this class is tested mostly in DeploymentPlan::ReleaseVersion spec.
  # In the future these tests can be migrated to here.
  describe '#add_link_info' do
    subject(:template) { described_class.new(nil, 'foo') }
    before {
        template.add_link_info('job_name', 'provides', 'link_name', {'name'=>'link_name','type'=>'type', 'properties'=>['plant']})
        template.add_link_info('job_name', 'provides', 'link_name', {'from'=>'link_name'})
    }

    context 'given properly formated arguments' do
      it 'should populate link_infos' do
        expect(template.link_infos).to eq({"job_name"=>{"provides"=>{"link_name"=>{"name"=>"link_name", "type"=>"type","properties"=>["plant"], "from"=>"link_name"}}}})
      end
    end
  end
end
