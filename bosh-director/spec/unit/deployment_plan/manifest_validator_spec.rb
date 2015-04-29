require 'spec_helper'

module Bosh
  module Director
    describe DeploymentPlan::ManifestValidator do
      subject(:validator) { described_class.new }

      describe '#validate!' do
        it 'requires name to be a string' do
          manifest = {}
          expect {
            validator.validate!(manifest)
          }.to raise_error(ManifestValidationError, /name must be a string/)
        end

        it 'requires properties to be a hash if present' do
          manifest = {'name' => 'name', 'properties' => 'not-a-hash'}
          expect {
            validator.validate!(manifest)
          }.to raise_error(ManifestValidationError, /properties must be a hash/)
        end

        describe 'releases' do
          it 'requires that the releases key be an array if present' do
            manifest = {'name' => 'name', 'releases' => 'not-an-array'}
            expect {
              validator.validate!(manifest)
            }.to raise_error(ManifestValidationError, /releases must be an array/)
          end

          it 'requires each release.name to be a string' do
            manifest = {'name' => 'name', 'releases' => [{}]}
            expect {
              validator.validate!(manifest)
            }.to raise_error(ManifestValidationError, /releases\[0\].name must be a string/)
          end

          it 'requires that no releases have duplicate names' do
            releases = [
              {'name' => 'release-name'},
              {'name' => 'release-name'}
            ]
            manifest = {'name' => 'name', 'releases' => releases}
            expect {
              validator.validate!(manifest)
            }.to raise_error(ManifestValidationError, /release name 'release-name' must be unique/)
          end
        end
      end
    end
  end
end
