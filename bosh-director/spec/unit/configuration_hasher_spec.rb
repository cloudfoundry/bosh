require 'spec_helper'

describe Bosh::Director::ConfigurationHasher do
  let(:instance_class) { Struct.new(:index, :spec, :configuration_hash, :template_hashes) }

  it 'should hash a simple job' do
    template = Bosh::Director::Models::Template.make(blobstore_id: 'b_id')

    template_contents = create_job('foo', 'monit file',
                                   { 'test' => {
                                     'destination' => 'test_dst',
                                     'contents' => 'test contents' }
                                   })

    tmp_file = Tempfile.new('blob')
    File.open(tmp_file.path, 'w') { |f| f.write(template_contents) }
    template_spec = double('template_spec',
                           template: template,
                           blobstore_id: 'b_id',
                           name: 'router',
                           download_blob: tmp_file.path)

    instance_spec = {
      'job' => { 'name' => 'foo' },
      'test' => 'spec',
      'properties' => { 'foo' => 'bar' },
      'index' => 0
    }
    instance = instance_class.new(0, instance_spec, nil, nil)

    job_spec = double('job_spec', name: 'foo', instances: [instance], templates: [template_spec])

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job_spec)
    configuration_hasher.hash

    expect(instance.configuration_hash).to eq('d4b58a62d2102a315f27bf8c41b4dfef672f785b')
    expect(instance.template_hashes).to eq('router' => 'd4b58a62d2102a315f27bf8c41b4dfef672f785b')
  end

  it 'should correctly hash a job with two templates and two instances' do
    template = Bosh::Director::Models::Template.make(blobstore_id: 'b_id')
    template_contents = create_job('foo', 'monit file',
                                   { 'test' => { 'destination' => 'test_dst',
                                                 'contents' => 'test contents index <%= index %>' } })
    tmp_file = Tempfile.new('blob')
    File.open(tmp_file.path, 'w') { |f| f.write(template_contents) }
    template_spec = double('template_spec',
                           template: template,
                           blobstore_id: 'b_id',
                           name: 'router',
                           download_blob: tmp_file.path)


    template2 = Bosh::Director::Models::Template.make(blobstore_id: 'b_id2')
    template_contents2 = create_job('foo', 'monit file',
                                    { 'test' => { 'destination' => 'test_dst',
                                                  'contents' => 'test contents2 <%= index %>' } })
    tmp_file2 = Tempfile.new('blob2')
    File.open(tmp_file2.path, 'w') { |f| f.write(template_contents2) }
    template_spec2 = double('template_spec',
                            template: template2,
                            blobstore_id: 'b_id2',
                            name: 'dashboard',
                            download_blob: tmp_file2.path)

    instance_spec = {
      'job' => { 'name' => 'foo' },
      'test' => 'spec',
      'properties' => { 'foo' => 'bar' },
      'index' => 0
    }
    instance = instance_class.new(0, instance_spec, nil, nil)

    instance_spec2 = {
      'job' => { 'name' => 'foo' },
      'test' => 'spec',
      'properties' => { 'foo' => 'bar' },
      'index' => 1
    }
    instance2 = instance_class.new(0, instance_spec2, nil, nil)

    job_spec = double('job_spec', name: 'foo', instances: [instance, instance2], templates: [template_spec, template_spec2])

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job_spec)
    configuration_hasher.hash

    expect(instance.configuration_hash).to eq('9a01d5eaef2466439cf5f47c817917869bf7382b')
    expect(instance.template_hashes).to eq('dashboard' => 'b22dc37828aa4596f715a4d1d9a77bc999fb0f68', 'router' => 'cdb03dd7e933d087030dc734d7515c8715dfadc0')
    expect(instance2.configuration_hash).to eq('1ac87f1ff406553944d7bf1e3dc2ad224d50cc80')
    expect(instance2.template_hashes).to eq('dashboard' => 'a06db619abd6eaa32a5ec848894486f162ede0ad', 'router' => '924386b29900dccb55b7a559ce24b9c3c1c9eff0')
  end

  it 'should expose the job context to the templates' do
    template = Bosh::Director::Models::Template.make(blobstore_id: 'b_id')
    text = '<%= name %> <%= index %> <%= properties.foo %> <%= spec.test %>'
    template_contents = create_job('foo', text,
                                   { 'test' => {
                                     'destination' => 'test_dst',
                                     'contents' => '<%= index %>'
                                   } })

    tmp_file = Tempfile.new('blob')
    File.open(tmp_file.path, 'w') { |f| f.write(template_contents) }

    template_spec = double('template_spec',
                           template: template,
                           name: 'router',
                           download_blob: tmp_file.path)

    instance_spec = {
      'job' => { 'name' => 'foo' },
      'test' => 'spec',
      'properties' => { 'foo' => 'bar' },
      'index' => 0
    }
    instance = instance_class.new(0, instance_spec, nil, nil)

    job_spec = double('job_spec', name: 'foo', instances: [instance], templates: [template_spec])

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job_spec)
    configuration_hasher.hash

    expect(instance.configuration_hash).to eq('1ec0fb915dd041e4e121ccd1464b88a9aed1ee60')
    expect(instance.template_hashes).to eq('router' => '1ec0fb915dd041e4e121ccd1464b88a9aed1ee60')
  end

  it 'should give helpful error messages when rendering monit template' do
    template = Bosh::Director::Models::Template.make(blobstore_id: 'b_id')


    text = "<%= name %>\n <%= index %>\n <%= properties.testing.foo %> <%= spec.test %>"
    template_contents = create_job('foo',
                                   text,
                                   { 'test' => {
                                     'destination' => 'test_dst',
                                     'contents' => '<%= index %>'
                                   } })

    tmp_file = Tempfile.new('blob')
    File.open(tmp_file.path, 'w') { |f| f.write(template_contents) }
    template_spec = double('template_spec',
                           template: template,
                           name: 'router',
                           download_blob: tmp_file.path)

    instance_spec = {
      'job' => { 'name' => 'foo' },
      'test' => 'spec',
      'properties' => { 'foo' => 'bar' },
      'index' => 0
    }
    instance = instance_class.new(0, instance_spec, nil, nil)


    job_spec = double('job_spec', name: 'foo', instances: [instance], templates: [template_spec])

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job_spec)
    expect {
      configuration_hasher.hash
    }.to raise_error("Error filling in template `monit' for `foo/0' (line 3: undefined method `foo' for nil:NilClass)")
  end

  it 'should give helpful error messages when rendering job templates' do
    template = Bosh::Director::Models::Template.make(blobstore_id: 'b_id')


    template_contents = create_job('foo',
                                   'monit file',
                                   { 'test' => {
                                     'destination' => 'test_dst',
                                     'contents' => '<%= properties.testing.foo %> <%= index %>'
                                   } })

    tmp_file = Tempfile.new('blob')
    File.open(tmp_file.path, 'w') { |f| f.write(template_contents) }
    template_spec = double('template_spec',
                           template: template,
                           name: 'router',
                           download_blob: tmp_file.path)

    instance_spec = {
      'job' => { 'name' => 'foo' },
      'test' => 'spec',
      'properties' => { 'foo' => 'bar' },
      'index' => 0
    }
    instance = instance_class.new(0, instance_spec, nil, nil)

    job_spec = double('job_spec', name: 'foo', instances: [instance], templates: [template_spec])

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job_spec)
    expect {
      configuration_hasher.hash
    }.to raise_error("Error filling in template `test' for `foo/0' (line 1: undefined method `foo' for nil:NilClass)")
  end
end
