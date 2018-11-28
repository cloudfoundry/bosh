## bosh-certificate-info

This utility is a binary that when invoked will scan the filesystem under `var/vcap/jobs` to search for files named `validate-certificate.yml`.

It will open and parse this files in format of YAML and extract expiration dates of certificates placed there.

```json
{
  "var/vcap/jobs/blobstore/config/validate_certificate.yml": {
    "certificates": {
      "director.ssl.cert": {
        "expires": 0,
        "error_string": "failed to decode certificate"
      },
      "property-a.sub-key.sub-sub-key": {
        "expires": 1574372638,
        "error_string": ""
      },
      "property-b.sub-key.sub-sub-key": {
        "expires": 1574372638,
        "error_string": ""
      },
      "property-n.sub-key.sub-sub-key": {
        "expires": 0,
        "error_string": "failed to decode certificate"
      }
    },
    "error_string": ""
  },
  "var/vcap/jobs/director/config/validate_certificate.yml": {
    "certificates": {
      "director.ssl.cert": {
        "expires": 0,
        "error_string": "failed to decode certificate"
      },
      "property-a.sub-key.sub-sub-key": {
        "expires": 1574372638,
        "error_string": ""
      },
      "property-b.sub-key.sub-sub-key": {
        "expires": 1574372638,
        "error_string": ""
      },
      "property-n.sub-key.sub-sub-key": {
        "expires": 0,
        "error_string": "failed to decode certificate"
      }
    },
    "error_string": ""
  }
}
```