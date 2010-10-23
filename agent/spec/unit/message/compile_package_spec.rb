require File.dirname(__FILE__) + '/../../spec_helper'

describe Bosh::Agent::Message::CompilePackage do

  it 'should have a blobstore client' do
    handler = Bosh::Agent::Message::CompilePackage.new(nil)
    handler.blobstore_client.should be_an_instance_of Bosh::Blobstore::SimpleBlobstoreClient
  end

end
