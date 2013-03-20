require "spec_helper"

describe 'compilation' do

  before(:all) do
    requirement release
    requirement stemcell
  end

  after(:all) do
    cleanup release
    cleanup stemcell
  end

  before(:each) do
    load_deployment_spec
  end

  context 'when compiled package cache is enabled' do
    xit 'should download compiled package if it exist' do
      pending 'global package cache not enabled' unless compiled_package_cache?

      with_deployment do
        # do nothing, just to make sure the cache is warm
      end
      
      # delete release to force package compilation
      bosh("delete release #{release.name}", :on_error => :return)
      requirement release

      with_deployment do |deployment, result|
        puts result.output
        events(get_task_id(result.output)).any? { |event|
          event['task'].match(/Downloading '.+' from global cache/)
        }.should be_true
      end
    end
  end
end
