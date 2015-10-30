require 'spec_helper'

module Bosh::Director
  module Jobs::Helpers
    describe ReleaseVersionDeleter do

      subject(:release_version_deleter) { ReleaseVersionDeleter.new(blobstore, package_deleter, force, logger, event_log) }


      describe '#delete' do

      end
    end
  end
end
