require_relative '../../spec_helper'

describe 'inspect release', type: :integration do
  with_reset_sandbox_before_each

  context 'with a director targeted' do
    it 'prints an error when version is not specified' do
      out, exit_code = bosh_runner.run('inspect-release name-without-version', { return_exit_code: true, failure_expected: true })
      expect(out).to include("release 'name-without-version' to be in format 'name/version'")
      expect(exit_code).to eq(1)
    end

    it 'shows jobs and source pacakges' do
      bosh_runner.run("upload-release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")
      out = scrub_random_ids(table(bosh_runner.run('inspect-release test_release/1', json: true)))

      expect(out).to eq([
        {
          'job'=>'job_using_pkg_1/9a5f09364b2cdc18a45172c15dca21922b3ff196',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'a7d51f65cda79d2276dc9cc254e6fec523b07b02',
          'links_consumed' => '',
          'links_provided' => ''
        },
        {
          'job'=>'job_using_pkg_1_and_2/673c3689362f2adb37baed3d8d4344cf03ff7637',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'c9acbf245d4b4721141b54b26bee20bfa58f4b54',
          'links_consumed' => '',
          'links_provided' => ''
        },
        {
          'job'=>'job_using_pkg_2/8e9e3b5aebc7f15d661280545e9d1c1c7d19de74',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'79475b0b035fe70f13a777758065210407170ec3',
          'links_consumed' => '',
          'links_provided' => ''
        },
        {
          'job'=>'job_using_pkg_3/54120dd68fab145433df83262a9ba9f3de527a4b',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'ab4e6077ecf03399f215e6ba16153fd9ebbf1b5f',
          'links_consumed' => '',
          'links_provided' => ''
        },
        {
          'job'=>'job_using_pkg_4/0ebdb544f9c604e9a3512299a02b6f04f6ea6d0c',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'1ff32a12e0c574720dd8e5111834bac67229f5c1',
          'links_consumed' => '',
          'links_provided' => ''
        },
        {
          'job'=>'job_using_pkg_5/fb41300edf220b1823da5ab4c243b085f9f249af',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'37350e20c6f78ab96a1191e5d97981a8d2831665',
          'links_consumed' => '',
          'links_provided' => ''
        },
        {
          'package'=>'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f',
          'compiled_for'=>'(source)',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'93fade7dd8950d8a1dd2bf5ec751e478af3150e9'
        },
        {
          'package'=>'pkg_2/f5c1c303c2308404983cf1e7566ddc0a22a22154',
          'compiled_for'=>'(source)',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'b2751daee5ef20b3e4f3ebc3452943c28f584500'
        },
        {
          'package'=>'pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c',
          'compiled_for'=>'(source)',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'62fff2291aac72f5bd703dba0c5d85d0e23532e0'
        },
        {
          'package'=>'pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4',
          'compiled_for'=>'(source)',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'603f212d572b0307e4c51807c5e03c47944bb9c3'
        },
        {
          'package'=>'pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4',
          'compiled_for'=>'(source)',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'ad733ca76ab4747747d8f9f1ddcfa568519a2e00'
        }
      ])
    end

    it 'shows jobs and packages compiled against multiple stemcells' do
      bosh_runner.run("upload-stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.tgz')}")
      out = scrub_random_ids(table(bosh_runner.run('inspect-release test_release/1', json: true)))

      expect(out).to eq([
        {
          'job'=>'job_using_pkg_1/9a5f09364b2cdc18a45172c15dca21922b3ff196',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'a7d51f65cda79d2276dc9cc254e6fec523b07b02',
          'links_consumed' => '',
          'links_provided' => ''
        },
        {
          'job'=>'job_using_pkg_1_and_2/673c3689362f2adb37baed3d8d4344cf03ff7637',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'c9acbf245d4b4721141b54b26bee20bfa58f4b54',
          'links_consumed' => '',
          'links_provided' => ''
        },
        {
          'job'=>'job_using_pkg_2/8e9e3b5aebc7f15d661280545e9d1c1c7d19de74',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'79475b0b035fe70f13a777758065210407170ec3',
          'links_consumed' => '',
          'links_provided' => ''
        },
        {
          'job'=>'job_using_pkg_3/54120dd68fab145433df83262a9ba9f3de527a4b',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'ab4e6077ecf03399f215e6ba16153fd9ebbf1b5f',
          'links_consumed' => '',
          'links_provided' => ''
        },
        {
          'job'=>'job_using_pkg_4/0ebdb544f9c604e9a3512299a02b6f04f6ea6d0c',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'1ff32a12e0c574720dd8e5111834bac67229f5c1',
          'links_consumed' => '',
          'links_provided' => ''
        },
        {
          'job'=>'job_using_pkg_5/fb41300edf220b1823da5ab4c243b085f9f249af',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'37350e20c6f78ab96a1191e5d97981a8d2831665',
          'links_consumed' => '',
          'links_provided' => ''
        },
        {
          'package'=>'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f',
          'compiled_for'=>'(source)',
          'blobstore_id'=>'',
          'digest'=>''
        },
        {
          'package'=>'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f',
          'compiled_for'=>'centos-7/3001',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'735987b52907d970106f38413825773eec7cc577'
        },
        {
          'package'=>'pkg_2/f5c1c303c2308404983cf1e7566ddc0a22a22154',
          'compiled_for'=>'(source)',
          'blobstore_id'=>'',
          'digest'=>''
        },
        {
          'package'=>'pkg_2/f5c1c303c2308404983cf1e7566ddc0a22a22154',
          'compiled_for'=>'centos-7/3001',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'5b21895211d8592c129334e3d11bd148033f7b82'
        },
        {
          'package'=>'pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c',
          'compiled_for'=>'(source)',
          'blobstore_id'=>'',
          'digest'=>''
        },
        {
          'package'=>'pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c',
          'compiled_for'=>'centos-7/3001',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'f5cc94a01d2365bbeea00a4765120a29cdfb3bd7'
        },
        {
          'package'=>'pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4',
          'compiled_for'=>'(source)',
          'blobstore_id'=>'',
          'digest'=>''
        },
        {
          'package'=>'pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4',
          'compiled_for'=>'centos-7/3001',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'f21275861158ad864951faf76da0dce9c1b5f215'
        },
        {
          'package'=> 'pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4',
          'compiled_for'=>'(source)',
          'blobstore_id'=>'',
          'digest'=>''
        },
        {
          'package'=> 'pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4',
          'compiled_for'=>'centos-7/3001',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'002deec46961440df01c620be491e5b12246c5df'
        }
      ])
    end

    it 'shows consumed and provided links of release jobs' do
      bosh_runner.run("upload-release #{spec_asset('links_releases/release_with_optional_links-0+dev.1.tgz')}")
      out = scrub_random_ids(table(bosh_runner.run('inspect-release release_with_optional_links/0+dev.1', json: true)))

      expect(out).to eq([
        {
          'job'=>'api_server/a910dd03699797ba52f73f56f70475c794f9ff43',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'1e1ccbc60fefa8713c9c52510968bf0399f7dfda',
          'links_consumed' => "- name: db\n  type: db\n  optional: true\n- name: backup_db\n  type: db",
          'links_provided' => ''
        },
        {
          'job'=>'backup_database/2ea09882747364709dad9f45267965ac176ae5ad',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'46965969e112507cfb29119052a864e40f785d80',
          'links_consumed' => '',
          'links_provided' => "- name: backup_db\n  type: db"
        },
        {
          'job'=>'database/a9f952f94a82c13a3129ac481030f704a33d027f',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'9fbd6941108389f769c8f7dafc93410c386f1bd5',
          'links_consumed' => '',
          'links_provided' => "- name: db\n  type: db"
        },
        {
          'job'=>'mongo_db/1a57f0be3eb19e263261536693db0d5a521261a6',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'36705751b05ab71b9580d82f8347b71f7de31f0b',
          'links_consumed' => '',
          'links_provided' => "- name: read_only_db\n  type: db"

        },
        {
          'job'=>'node/20df71b951455e465845eab32743822693977b30',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'db867641e909c4ab1d22bb86037489530ee7d7f1',
          'links_consumed' => "- name: node1\n  type: node1\n- name: node2\n  type: node2\n  optional: true",
          'links_provided' => "- name: node1\n  type: node1\n- name: node2\n  type: node2"
        },
        {
          'package'=>'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f',
          'compiled_for'=>'(source)',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'cbf4e5b05e58f31076c124c343485f6a758b2c34'
        },
        {
          'package'=>'pkg_2/4b74be7d5aa14487c7f7b0d4516875f7c0eeb010',
          'compiled_for'=>'(source)',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'c49e3985d896d13d7da7fc99f66b0ad43c0ac417'
        },
        {
          'package'=>'pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c',
          'compiled_for'=>'(source)',
          'blobstore_id'=>'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'digest'=>'3ba0f08957427b0e7f060ee059473a632a712d1f'
        }
			])
    end
  end
end
