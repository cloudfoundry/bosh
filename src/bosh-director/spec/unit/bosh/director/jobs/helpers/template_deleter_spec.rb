require 'spec_helper'

module Bosh::Director
  module Jobs::Helpers
    describe TemplateDeleter do
      subject(:template_deleter) { TemplateDeleter.new(blobstore, per_spec_logger) }
      let(:blobstore) { instance_double(Bosh::Director::Blobstore::Client) }
      let(:release_version) { FactoryBot.create(:models_release_version) }
      let(:template) { FactoryBot.create(:models_template, blobstore_id: 'template-blob-id') }

      before do
        release_version.add_template(template)
        allow(blobstore).to receive(:delete)
      end

      describe 'deleting a template' do
        describe 'when not forced' do
          let(:force) { false }

          it 'deletes the template blob' do
            expect(blobstore).to receive(:delete).with('template-blob-id')
            template_deleter.delete(template, force)
          end

          it 'disassociates with release versions' do
            template_deleter.delete(template, force)
            expect(release_version.templates).to be_empty
          end

          it 'destroys the template' do
            template_deleter.delete(template, force)
            expect(Models::Template.all).to be_empty
          end

          it 'should have no errors' do
            template_deleter.delete(template, force)
          end

          context 'when deleting the blob fails' do
            before do
              allow(blobstore).to receive(:delete).and_raise('wont')
            end
            it 'destroys the template' do
              expect{ template_deleter.delete(template, force) }.to raise_error(/wont/)
              expect(Models::Template.all).to_not be_empty
            end
          end
        end

        describe 'when forced' do
          let(:force) { true }

          it 'deletes the template blob' do
            expect(blobstore).to receive(:delete).with('template-blob-id')
            template_deleter.delete(template, force)
          end

          it 'disassociates with release versions' do
            template_deleter.delete(template, force)
            expect(release_version.templates).to be_empty
          end

          it 'destroys the template' do
            template_deleter.delete(template, force)
            expect(Models::Template.all).to be_empty
          end

          it 'should have no errors' do
            template_deleter.delete(template, force)
          end

          context 'when deleting the blob fails' do
            before do
              allow(blobstore).to receive(:delete).and_raise('wont')
            end
            it 'destroys the template' do
              template_deleter.delete(template, force)
              expect(Models::Template.all).to be_empty
            end
          end
        end
      end
    end
  end
end
