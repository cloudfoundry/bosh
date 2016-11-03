#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh

: ${BOSH_VSPHERE_VCENTER:?}
: ${BOSH_VSPHERE_VCENTER_USER:?}
: ${BOSH_VSPHERE_VCENTER_PASSWORD:?}
: ${BOSH_VSPHERE_VERSION:?}
: ${BOSH_VSPHERE_VCENTER_DC:?}
: ${BOSH_VSPHERE_VCENTER_CLUSTER:?}
: ${BOSH_VSPHERE_VCENTER_VM_FOLDER:?}
: ${BOSH_VSPHERE_VCENTER_TEMPLATE_FOLDER:?}
: ${BOSH_VSPHERE_VCENTER_DATASTORE:?}
: ${BOSH_VSPHERE_VCENTER_DISK_PATH:?}
: ${BOSH_VSPHERE_VCENTER_VLAN:?}
: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}
: ${USE_REDIS:=false}
: ${SSLIP_IO_KEY:?}

# inputs
# paths will be resolved in a separate task so use relative paths
BOSH_RELEASE_URI="file://$(echo bosh-release/*.tgz)"
CPI_RELEASE_URI="file://$(echo cpi-release/*.tgz)"
STEMCELL_URI="file://$(echo stemcell/*.tgz)"

# outputs
output_dir="$(realpath director-config)"

# environment
env_name=$(cat environment/name)
metadata=$(cat environment/metadata)
network1=$(env_attr "${metadata}" "network1")
echo Using environment: \'${env_name}\'
: ${DIRECTOR_IP:=$(                  env_attr "${metadata}" "directorIP" )}
: ${BOSH_VSPHERE_VCENTER_CIDR:=$(    env_attr "${network1}" "vCenterCIDR" )}
: ${BOSH_VSPHERE_VCENTER_GATEWAY:=$( env_attr "${network1}" "vCenterGateway" )}
: ${BOSH_VSPHERE_DNS:=$(             env_attr "${metadata}" "DNS" )}

redis_job=""
if [ "${USE_REDIS}" == true ]; then
  redis_job="- {name: redis, release: bosh}"
fi

# env file generation
cat > "${output_dir}/director.env" <<EOF
#!/usr/bin/env bash

export BOSH_DIRECTOR_IP=${DIRECTOR_IP}
export BOSH_DIRECTOR_USERNAME=${BOSH_DIRECTOR_USERNAME}
export BOSH_DIRECTOR_PASSWORD=${BOSH_DIRECTOR_PASSWORD}
EOF

cat > "${output_dir}/director.yml" <<EOF
---
name: certification-director

releases:
  - name: bosh
    url: ${BOSH_RELEASE_URI}
  - name: bosh-vsphere-cpi
    url: ${CPI_RELEASE_URI}

resource_pools:
  - name: vms
    network: private
    stemcell:
      url: ${STEMCELL_URI}
    cloud_properties:
      cpu: 2
      ram: 4_096
      disk: 20_000

disk_pools:
  - name: disks
    disk_size: 20_000
    cloud_properties:
      datastores: [${BOSH_VSPHERE_VCENTER_DATASTORE}]

networks:
  - name: private
    type: manual
    subnets:
      - range: ${BOSH_VSPHERE_VCENTER_CIDR}
        gateway: ${BOSH_VSPHERE_VCENTER_GATEWAY}
        dns: [${BOSH_VSPHERE_DNS}]
        cloud_properties: {name: ${BOSH_VSPHERE_VCENTER_VLAN}}

jobs:
  - name: bosh
    instances: 1

    templates:
      - {name: nats, release: bosh}
      - {name: postgres, release: bosh}
      - {name: blobstore, release: bosh}
      - {name: director, release: bosh}
      - {name: health_monitor, release: bosh}
      - {name: powerdns, release: bosh}
      - {name: vsphere_cpi, release: bosh-vsphere-cpi}
      ${redis_job}

    resource_pool: vms
    persistent_disk_pool: disks

    networks:
      - {name: private, static_ips: [${DIRECTOR_IP}]}

    properties:
      nats:
        address: 127.0.0.1
        user: nats
        password: nats-password

      postgres: &db
        host: 127.0.0.1
        user: postgres
        password: postgres-password
        database: bosh
        adapter: postgres

      # required for some upgrade paths
      redis:
        listen_addresss: 127.0.0.1
        address: 127.0.0.1
        password: redis-password

      blobstore:
        address: ${DIRECTOR_IP}
        port: 25250
        provider: dav
        director: {user: director, password: director-password}
        agent: {user: agent, password: agent-password}

      director:
        address: 127.0.0.1
        name: certification-director
        db: *db
        cpi_job: vsphere_cpi
        user_management:
          provider: local
          local:
            users:
              - {name: ${BOSH_DIRECTOR_USERNAME}, password: ${BOSH_DIRECTOR_PASSWORD}}
        ssl:
          key: "$(sed 's/$/\\n/g' <<< "${SSLIP_IO_KEY}" | tr -d '\n')"
          cert: |
            -----BEGIN CERTIFICATE-----
            MIIFYzCCBEugAwIBAgIQHowj0iaZfd9jx4pfXaJ7UzANBgkqhkiG9w0BAQsFADCB
            kDELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4G
            A1UEBxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxNjA0BgNV
            BAMTLUNPTU9ETyBSU0EgRG9tYWluIFZhbGlkYXRpb24gU2VjdXJlIFNlcnZlciBD
            QTAeFw0xNTA5MTEwMDAwMDBaFw0xODA5MTAyMzU5NTlaMFsxITAfBgNVBAsTGERv
            bWFpbiBDb250cm9sIFZhbGlkYXRlZDEhMB8GA1UECxMYUG9zaXRpdmVTU0wgTXVs
            dGktRG9tYWluMRMwEQYDVQQDDAoqLnNzbGlwLmlvMIIBIjANBgkqhkiG9w0BAQEF
            AAOCAQ8AMIIBCgKCAQEAvQIIb62gT2oGm4xFBjQsVTOCv3cYVBIRieB9Da4NmRmg
            Dv+V7eBqT09jpIc26FYVzwZf/SCpOh7VXDa7fzklz0KSBfnPq2TkO1y2QkOwTAdP
            uex+jmvM2JeF3HtbzMC649225/DfWQFwv6XNqQnKPlSl4ntEcXh/7D1RC8nXQxYa
            FY1iKBQZamzNT3X3Q9L84by3MQ2UbbI/36q3Wz5hap87vpp9zInmJqs2FUaRd3IR
            1AjaF8fDeT/3e6oxslj9N1JeuaQDBa1n24WKsdGkB9N+R7l4h1a91bEGod2+AZwy
            v0OMd3faE05ApXZrCB6bypEBbpPexG34ZIZGriF9xwIDAQABo4IB6zCCAecwHwYD
            VR0jBBgwFoAUkK9qOpRaC9iQ6hJWc99DtDoo2ucwHQYDVR0OBBYEFLdnLOxPsBs+
            eks6jVZAk0Zoz67IMA4GA1UdDwEB/wQEAwIFoDAMBgNVHRMBAf8EAjAAMB0GA1Ud
            JQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjBPBgNVHSAESDBGMDoGCysGAQQBsjEB
            AgIHMCswKQYIKwYBBQUHAgEWHWh0dHBzOi8vc2VjdXJlLmNvbW9kby5jb20vQ1BT
            MAgGBmeBDAECATBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vY3JsLmNvbW9kb2Nh
            LmNvbS9DT01PRE9SU0FEb21haW5WYWxpZGF0aW9uU2VjdXJlU2VydmVyQ0EuY3Js
            MIGFBggrBgEFBQcBAQR5MHcwTwYIKwYBBQUHMAKGQ2h0dHA6Ly9jcnQuY29tb2Rv
            Y2EuY29tL0NPTU9ET1JTQURvbWFpblZhbGlkYXRpb25TZWN1cmVTZXJ2ZXJDQS5j
            cnQwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmNvbW9kb2NhLmNvbTA5BgNVHREE
            MjAwggoqLnNzbGlwLmlvggwqLnguc3NsaXAuaW+CCHNzbGlwLmlvggp4LnNzbGlw
            LmlvMA0GCSqGSIb3DQEBCwUAA4IBAQB09lURpTM1LHIkhOvmc/OsJ2GoDdyQlw0m
            KWkWGlROcvsxcyoltWGRrgNyqXzhURLSNSrXtj5awz05A3/81CnJiN1TUMOAQjXj
            knw7Zbe6j1WfI/RJVd3gIo2IKl0VtIPR6o0HSI8Odfs8TP8Pw8tAWOyh8NtMG8P3
            ot5L4/f6+6jTiXLAFIV4Hi60+HbUc7ZnVfjiFExZCt0It5lcTikh7Y4GYaVmvdRG
            09TYnAMxTx4eRTkbrvq0EFGyyBQuxG2pEIBiJ8s0JqO1KtvGhF92f7Cu8z7qxlcm
            hFK2Y0EENB1Tj9uBcmos9bKF5Mt+DqonXhB31Tyj8b17aEdc5hXU
            -----END CERTIFICATE-----
            -----BEGIN CERTIFICATE-----
            MIIGCDCCA/CgAwIBAgIQKy5u6tl1NmwUim7bo3yMBzANBgkqhkiG9w0BAQwFADCB
            hTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4G
            A1UEBxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxKzApBgNV
            BAMTIkNPTU9ETyBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTQwMjEy
            MDAwMDAwWhcNMjkwMjExMjM1OTU5WjCBkDELMAkGA1UEBhMCR0IxGzAZBgNVBAgT
            EkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMR
            Q09NT0RPIENBIExpbWl0ZWQxNjA0BgNVBAMTLUNPTU9ETyBSU0EgRG9tYWluIFZh
            bGlkYXRpb24gU2VjdXJlIFNlcnZlciBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEP
            ADCCAQoCggEBAI7CAhnhoFmk6zg1jSz9AdDTScBkxwtiBUUWOqigwAwCfx3M28Sh
            bXcDow+G+eMGnD4LgYqbSRutA776S9uMIO3Vzl5ljj4Nr0zCsLdFXlIvNN5IJGS0
            Qa4Al/e+Z96e0HqnU4A7fK31llVvl0cKfIWLIpeNs4TgllfQcBhglo/uLQeTnaG6
            ytHNe+nEKpooIZFNb5JPJaXyejXdJtxGpdCsWTWM/06RQ1A/WZMebFEh7lgUq/51
            UHg+TLAchhP6a5i84DuUHoVS3AOTJBhuyydRReZw3iVDpA3hSqXttn7IzW3uLh0n
            c13cRTCAquOyQQuvvUSH2rnlG51/ruWFgqUCAwEAAaOCAWUwggFhMB8GA1UdIwQY
            MBaAFLuvfgI9+qbxPISOre44mOzZMjLUMB0GA1UdDgQWBBSQr2o6lFoL2JDqElZz
            30O0Oija5zAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNV
            HSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwGwYDVR0gBBQwEjAGBgRVHSAAMAgG
            BmeBDAECATBMBgNVHR8ERTBDMEGgP6A9hjtodHRwOi8vY3JsLmNvbW9kb2NhLmNv
            bS9DT01PRE9SU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDBxBggrBgEFBQcB
            AQRlMGMwOwYIKwYBBQUHMAKGL2h0dHA6Ly9jcnQuY29tb2RvY2EuY29tL0NPTU9E
            T1JTQUFkZFRydXN0Q0EuY3J0MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21v
            ZG9jYS5jb20wDQYJKoZIhvcNAQEMBQADggIBAE4rdk+SHGI2ibp3wScF9BzWRJ2p
            mj6q1WZmAT7qSeaiNbz69t2Vjpk1mA42GHWx3d1Qcnyu3HeIzg/3kCDKo2cuH1Z/
            e+FE6kKVxF0NAVBGFfKBiVlsit2M8RKhjTpCipj4SzR7JzsItG8kO3KdY3RYPBps
            P0/HEZrIqPW1N+8QRcZs2eBelSaz662jue5/DJpmNXMyYE7l3YphLG5SEXdoltMY
            dVEVABt0iN3hxzgEQyjpFv3ZBdRdRydg1vs4O2xyopT4Qhrf7W8GjEXCBgCq5Ojc
            2bXhc3js9iPc0d1sjhqPpepUfJa3w/5Vjo1JXvxku88+vZbrac2/4EjxYoIQ5QxG
            V/Iz2tDIY+3GH5QFlkoakdH368+PUq4NCNk+qKBR6cGHdNXJ93SrLlP7u3r7l+L4
            HyaPs9Kg4DdbKDsx5Q5XLVq4rXmsXiBmGqW5prU5wfWYQ//u+aen/e7KJD2AFsQX
            j4rBYKEMrltDR5FL1ZoXX/nUh8HCjLfn4g8wGTeGrODcQgPmlKidrv0PJFGUzpII
            0fxQ8ANAe4hZ7Q7drNJ3gjTcBpUC2JD5Leo31Rpg0Gcg19hCC0Wvgmje3WYkN5Ap
            lBlGGSW4gNfL1IYoakRwJiNiqZ+Gb7+6kHDSVneFeO/qJakXzlByjAA6quPbYzSf
            +AZxAeKCINT+b72x
            -----END CERTIFICATE-----
            -----BEGIN CERTIFICATE-----
            MIIFdDCCBFygAwIBAgIQJ2buVutJ846r13Ci/ITeIjANBgkqhkiG9w0BAQwFADBv
            MQswCQYDVQQGEwJTRTEUMBIGA1UEChMLQWRkVHJ1c3QgQUIxJjAkBgNVBAsTHUFk
            ZFRydXN0IEV4dGVybmFsIFRUUCBOZXR3b3JrMSIwIAYDVQQDExlBZGRUcnVzdCBF
            eHRlcm5hbCBDQSBSb290MB4XDTAwMDUzMDEwNDgzOFoXDTIwMDUzMDEwNDgzOFow
            gYUxCzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAO
            BgNVBAcTB1NhbGZvcmQxGjAYBgNVBAoTEUNPTU9ETyBDQSBMaW1pdGVkMSswKQYD
            VQQDEyJDT01PRE8gUlNBIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MIICIjANBgkq
            hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAkehUktIKVrGsDSTdxc9EZ3SZKzejfSNw
            AHG8U9/E+ioSj0t/EFa9n3Byt2F/yUsPF6c947AEYe7/EZfH9IY+Cvo+XPmT5jR6
            2RRr55yzhaCCenavcZDX7P0N+pxs+t+wgvQUfvm+xKYvT3+Zf7X8Z0NyvQwA1onr
            ayzT7Y+YHBSrfuXjbvzYqOSSJNpDa2K4Vf3qwbxstovzDo2a5JtsaZn4eEgwRdWt
            4Q08RWD8MpZRJ7xnw8outmvqRsfHIKCxH2XeSAi6pE6p8oNGN4Tr6MyBSENnTnIq
            m1y9TBsoilwie7SrmNnu4FGDwwlGTm0+mfqVF9p8M1dBPI1R7Qu2XK8sYxrfV8g/
            vOldxJuvRZnio1oktLqpVj3Pb6r/SVi+8Kj/9Lit6Tf7urj0Czr56ENCHonYhMsT
            8dm74YlguIwoVqwUHZwK53Hrzw7dPamWoUi9PPevtQ0iTMARgexWO/bTouJbt7IE
            IlKVgJNp6I5MZfGRAy1wdALqi2cVKWlSArvX31BqVUa/oKMoYX9w0MOiqiwhqkfO
            KJwGRXa/ghgntNWutMtQ5mv0TIZxMOmm3xaG4Nj/QN370EKIf6MzOi5cHkERgWPO
            GHFrK+ymircxXDpqR+DDeVnWIBqv8mqYqnK8V0rSS527EPywTEHl7R09XiidnMy/
            s1Hap0flhFMCAwEAAaOB9DCB8TAfBgNVHSMEGDAWgBStvZh6NLQm9/rEJlTvA73g
            JMtUGjAdBgNVHQ4EFgQUu69+Aj36pvE8hI6t7jiY7NkyMtQwDgYDVR0PAQH/BAQD
            AgGGMA8GA1UdEwEB/wQFMAMBAf8wEQYDVR0gBAowCDAGBgRVHSAAMEQGA1UdHwQ9
            MDswOaA3oDWGM2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9BZGRUcnVzdEV4dGVy
            bmFsQ0FSb290LmNybDA1BggrBgEFBQcBAQQpMCcwJQYIKwYBBQUHMAGGGWh0dHA6
            Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcNAQEMBQADggEBAGS/g/FfmoXQ
            zbihKVcN6Fr30ek+8nYEbvFScLsePP9NDXRqzIGCJdPDoCpdTPW6i6FtxFQJdcfj
            Jw5dhHk3QBN39bSsHNA7qxcS1u80GH4r6XnTq1dFDK8o+tDb5VCViLvfhVdpfZLY
            Uspzgb8c8+a4bmYRBbMelC1/kZWSWfFMzqORcUx8Rww7Cxn2obFshj5cqsQugsv5
            B5a6SE2Q8pTIqXOi6wZ7I53eovNNVZ96YUWYGGjHXkBrI/V5eu+MtWuLt29G9Hvx
            PUsE2JOAWVrgQSQdso8VYFhH2+9uRv0V9dlfmrPb2LjkQLPNlzmuhbsdjrzch5vR
            pu/xO28QOG8=
            -----END CERTIFICATE-----

      hm:
        http: {user: hm, password: hm-password}
        director_account: {user: ${BOSH_DIRECTOR_USERNAME}, password: ${BOSH_DIRECTOR_PASSWORD}}
        resurrector_enabled: true

      agent: {mbus: "nats://nats:nats-password@${DIRECTOR_IP}:4222"}

      dns:
        address: 127.0.0.1
        db: *db

      vcenter: &vcenter
        address: ${BOSH_VSPHERE_VCENTER}
        user: ${BOSH_VSPHERE_VCENTER_USER}
        password: ${BOSH_VSPHERE_VCENTER_PASSWORD}
        datacenters:
          - name: ${BOSH_VSPHERE_VCENTER_DC}
            vm_folder: ${BOSH_VSPHERE_VCENTER_VM_FOLDER}
            template_folder: ${BOSH_VSPHERE_VCENTER_TEMPLATE_FOLDER}
            datastore_pattern: ${BOSH_VSPHERE_VCENTER_DATASTORE}
            persistent_datastore_pattern: ${BOSH_VSPHERE_VCENTER_DATASTORE}
            disk_path: ${BOSH_VSPHERE_VCENTER_DISK_PATH}
            clusters: [${BOSH_VSPHERE_VCENTER_CLUSTER}]

cloud_provider:
  template: {name: vsphere_cpi, release: bosh-vsphere-cpi}

  mbus: "https://mbus:mbus-password@${DIRECTOR_IP}:6868"

  properties:
    vcenter: *vcenter
    agent: {mbus: "https://mbus:mbus-password@0.0.0.0:6868"}
    blobstore: {provider: local, path: /var/vcap/micro_bosh/data/cache}
    ntp: [0.pool.ntp.org, 1.pool.ntp.org]
EOF
