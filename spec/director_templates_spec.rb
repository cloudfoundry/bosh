require 'rspec'
require 'bosh/template/evaluation_context'
require_relative './template_example_group'

describe 'director tempaltes' do
 describe 'director' do
   describe 'nats_client_certificate.pem.erb' do
     it_should_behave_like 'a rendered file' do
       let(:file_name) { '../jobs/director/templates/nats_client_certificate.pem.erb' }
       let(:properties) do
         {
           'properties' => {
             'nats' => {
               'tls' => {
                 'director' => {
                   'certificate' => content
                 }
               }
             }
           }
         }
       end
     end
   end

   describe 'nats_client_private_key.erb' do
     it_should_behave_like 'a rendered file' do
       let(:file_name) { '../jobs/director/templates/nats_client_private_key.erb' }
       let(:properties) do
         {
           'properties' => {
             'nats' => {
               'tls' => {
                 'director' => {
                   'private_key' => content
                 }
               }
             }
           }
         }
       end
     end
   end
 end

 describe 'client ca' do
   describe 'nats_client_ca_certificate.pem.erb' do
     it_should_behave_like 'a rendered file' do
       let(:file_name) { '../jobs/director/templates/nats_client_ca_certificate.pem.erb' }
       let(:properties) do
         {
           'properties' => {
             'nats' => {
               'tls' => {
                 'client_ca' => {
                   'certificate' => content
                 }
               }
             }
           }
         }
       end
     end
   end

   describe 'nats_client_ca_private_key.erb' do
     it_should_behave_like 'a rendered file' do
       let(:file_name) { '../jobs/director/templates/nats_client_ca_private_key.erb' }
       let(:properties) do
         {
           'properties' => {
             'nats' => {
               'tls' => {
                 'client_ca' => {
                   'private_key' => content
                 }
               }
             }
           }
         }
       end
     end
   end
 end

end