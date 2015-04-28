require 'spec_helper'

module Bosh
  module Director
    describe DeploymentPlan::ManifestValidator do
      describe '#validate!' do
        it 'requires job_rename to be a hash if present'
        it 'requires job_states to be a hash if present'
        it 'requires name to be a string'
        it 'requires properties to be a hash if present'
        describe 'releases' do
          it 'requires that the releases key be an array if present'
          it 'requires each release.name to be a string' # from release_version.rb
          it 'requires each release.version to be a string'
          it 'requires that no releases have duplicate names'
        end
      end
    end
  end
end
