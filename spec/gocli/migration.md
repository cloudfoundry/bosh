When tests are broken due to a CLI bug, mark it as pending in the format of... 

    pending('cli2: #{story-id}: #{story-title}')

Then we're able to find all blocked tests with...

    grep -r 'pending(.cli2: #' spec/ | grep -v migration.md


When copying over files, replace the `require 'spec_helper'` with a `relative_require`...

    before:
    require 'spec_helper'

    after:
    require_relative '../spec_helper'


We dropped `--skip-if-exists`... always remove it from upload stemcell and upload release...

    s/ --skip-if-exists//

Ordering of stemcells and releases changed.

Add `json: true` to all bosh_runner.run calls for table parsing
 
    s/ (table.*bosh_runner.run[^\)])/\1, json: true/

Error numbers are no longer shown in output (confirmed with dk this is expected)...

    before:
    Error 100: Unable to render instance groups for deployment.
    
    after:
    Error: Unable to render instance groups for deployment.

    sed:
    s/Error( \d+):/Error:/

IP fields are now arrays... 

    before:
    expect(new_vms.map(&:ips)).to match_array(['192.168.1.10', '192.168.2.10'])
    
    after:
    expect(new_vms.map(&:ips).flatten).to match_array(['192.168.1.10', '192.168.2.10'])

Deleting deployments...

    before:
    delete deployment
    
    after:
    delete-deployment -d {deployment_name}

Exporting release...
 
    before:
    export release {release}/{release_version} {os}/{os_version}
     
    after:
    export-release -d {deployment_name} {release}/{release_version} {os}/{os_version}

Exported release artifact name...

    before:
    release-bosh-release-0.1-dev-on-toronto-os-stemcell-1.tgz
    
    after:
    bosh-release-0.1-dev-toronto-os-1-20160908-150958-078187308.tgz

Download manifest...

    before:
    download manifest
    
    after:
    download-manifest -d {deployment_name}


Create release...
 
    before:
    create release --with-tarball
    
    after:
    create-release --tarball

Run errand...

    before:
    run errand {errand_name}
    
    after:
    run-errand -d {deployment_name} {errand_name}

Output messages...

    before:
    Started updating job foobar
    
    after:
    Updating job foobar: 
