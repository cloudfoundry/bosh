include_recipe "ruby"

remote_file "/tmp/rubygems-#{node[:rubygems][:version]}.tgz" do
  source "http://production.cf.rubygems.org/rubygems/rubygems-#{node[:rubygems][:version]}.tgz"
  not_if { ::File.exists?("/tmp/rubygems-#{node[:rubygems][:version]}.tgz") }
end

bash "Install RubyGems" do
  cwd "/tmp"
  code <<-EOH
  tar xzf rubygems-#{node[:rubygems][:version]}.tgz
  cd rubygems-#{node[:rubygems][:version]}
  #{node[:ruby][:path]}/bin/ruby setup.rb
  EOH
  not_if do
    ::File.exists?("#{node[:ruby][:path]}/bin/gem") &&
        system("#{node[:ruby][:path]}/bin/gem -v | grep -q '#{node[:rubygems][:version]}$'")
  end
end

gem_package "bundler" do
  version node[:rubygems][:bundler][:version]
  gem_binary "#{node[:ruby][:path]}/bin/gem"
end