# bosh-common

## Unit testing your release ERB templates

The `Bosh::Common::Template::Test` package provides classes to unit-test your templates. These classes can be used to mock out different combinations of links, instances, etc., without the need to script a `create-release` and `deploy` against a running director.

Examples of usage are provided in `src/spec/config.erb_spec.rb` in `template-test-release`.

When you create your own release, you can likewise create a tests folder in your release and use these classes. A release author can create a test and call the template rendering like such:

```ruby
let(:job) {release.job('JOB-NAME')}  # e.g. 'web-server;
let(:template) {job.template('PATH-TO-TEMPLATE')}  # e.g. 'config/config-with-nested'
let(:manifest) do
  {
    'cert' => '----- BEGIN ... -----',
    'port' => 42,
  }
end
let(:instance) { InstanceSpec.new(name:'instance-name', az: 'az1', bootstrap: true) }
let(:link_instance) { InstanceSpec.new(name:'link-instance-name', az: 'az2') }
let(:link_properties) do
  { 'link-key' => 'link-value' }
end
let(:link) { Link.new(name:'link-name', instances:[link_instance], properties: link_properties)}


rendered_template = JSON.parse(template.render(manifest, spec: instance, consumes: [link]))
```

And then check that their template rendered as they expected.