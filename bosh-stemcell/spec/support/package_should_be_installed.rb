def package_should_be_installed(pkg)
  name, version = pkg.split(/:/)
  if version
    describe package(name) do
      it "should be installed with version #{version}" do
        expect(package(name)).to be_installed.with_version(version)
      end
    end
  else
    describe package(name) do
      it { should be_installed }
    end
  end
end
