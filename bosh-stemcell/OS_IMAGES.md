# OS Image Changes

OS images are stored in S3 bucket [bosh-os-images](http://s3.amazonaws.com/bosh-os-images/).


## Ubuntu 14.04

Ubuntu 14.04 images have filename `bosh-ubuntu-trusty-os-image.tgz`

* `0YARMwfbXRhCyma2hdTZTd97IlZqW3Qc`
  Add hmac-sha1 to sshd_config (required by go ssh lib)

* `G.Wzs2o9_mu6qvC2Nq7ZUvvo6jJSHjC8`
  update libgnutls26 to 2.12.23-12ubuntu2.2

* `Hcp6Wc4bQp9WB0i.y_2Z4qYzsO.7AXht`
  update libssl to 1.0.1f-1ubuntu2.11

* `jU0u9AnG550hgtZhH4TS30eU0lOJZxWn`
  update libc6 to 2.19-0ubuntu6.6
  update linux-headers to 3.16.0-31

* `bUE_h7edxT9PNKT6ntBKvXH8MzK3.wiA`
  update trusty to 14.04.2

* `O6Co_wDMuso7prheiIRVc_Q7_T1sC0EP`
  upgrade unzip to 6.0-9ubuntu1.3

* 'yacqn9ooY2Idc6Fb65QE25zl2MSvPX52'
  lock down sshd_config permissions
  disable weak ssh ciphers
  disable weak ssh MACs
  remove postfix

* 'TjC3SnsvaIhROEa1J1L77Mj21TRikCW0'
  upgrade unzip to 6.0-9ubuntu1.2

* `xIk.jCEzC5CrI.VrogNsyKRnHBtNIJ1w`
  Adds kernel flags to enable console output in openstack environments
  upgrade linux kernel to 3.13.0-45

* `LNYTMCODzn39poV8I4yUg1RxmAfTZPth`
  upgrade libssl to 1.0.1f-1ubuntu2.8

* `Wxp0XbijOQyo_pYgs3ctYQ0Dc6uPaO.I`
  switch logrotate to rotate based on size

* `QB8K.uFpJXHYJ4Nm.Of.CALZ_8Vh7sF2`
  start monit during agent bootstrap

* `shN71hxWcKt1xy54u8H6vcTJX3whZZ1y`
  disable reverse DNS resolution for sshd

* `VSHa.AirKTKl2thd3d.Ld0LZirE7kK8Z`
  enable rsyslog kernel logging

* `9_XaaM0qR6ReYHJvyJstqf52IL_1zJOQ`
  upgrade linux kernel to 3.13.0-39

* `omOTKc0mI6GFkX_HWgPAxfZicfQEvq2B`
  upgrade bash to 4.3-7ubuntu1.5
  upgrade libssl to 1.0.1f-1ubuntu2.7

* `qLay8YgGATMjiQZwWv0C26GZ7IUWy.qh`
  upgrade bash to 4.3-7ubuntu1.4

* `_pB.QMUs1y8oQAvDyjvGI9ccfIOtU0Do`
  upgrade bash to 4.3-7ubuntu1.3

* `GW4JUpDT_wsDu9TgsDRgXfcNBMVSfziW`
  upgrade bash to 4.3-7ubuntu1.2

* `9ysc4UIkmhpIhonEJzEeNbIpc8t38KxH`
  upgrade bash to 4.3-7ubuntu1.1

* `7956UhwNIGtYVKliAcpJFCO7iquWbhQR`
  install parted

* `cJItjk12ZCUgOo591c10FLHpAcVIwWDZ`
  update libgcrypt11 to 1.5.3-2ubuntu4.1
  update gnupg to 1.4.16-1ubuntu2.1

* `P9CaP1LYyF6DBXYWEf0G7mf2qY2z_l1D`
  update kernel to 3.13.0-35.62 and libc6 to 2.19-0ubuntu6.3

* `pGDuX7KzvJI7sXfGDU5obN8qxcD03e57`
  update kernel to 3.13.0-34.60

* `EhzrTcjEIEfEBBfcl3dnlBld2ZDjTveA`
  using latest libssl `1.0.1f-1ubuntu2`

* `KXC8x5eWAI71IOc_IelrkLEGNA6_cjRw`
  Remove resolv.conf clearing from firstboot.sh
  (3c785776c5093995e66bb1dce3253dfbeec51e40)

* `b8ix9.SJvvOTxDP5kV6cWNdkWpSxY6tn`
  update kernel to 3.13.0-32.56
  (d2be16d309d891cf4e2fe6ab3c21f4bb8f800c22)

* `kpMtaz33W38LnRuUL_ArWoNKIJwaS6Jb`
  using latest OpenSSL `1.0.1f`
  (23fe6fcd8518446cbdbec360c2f1e4b37834db88)

* `4oXc4U0orsQS944oCY_am5FqAqHXMhFK`
  update kernel to 3.13.0.29, updated syslog configuration
  (6927f02e9d3c02e6a7dfdece3d4802704572df2c)

* `ETW9GFwQPNRAknS1SSanJaVA__aL5PfN`
  swapaccount set, ca certifactes installed
  (f87f2cbd89da47f56e23d15ed232a41178587227)

* `FlU8d.nSgbEqmcr0ahmoTKNbk.lY95uq`
  Ubuntu 14.04
  (e448b0e8b0967288488c929fbbf953b22a046d1d)


## CentOS 6.6

CentOS 6.6 images have filename `bosh-centos-6_6-os-image.tgz`

* `kkUYP.4sM_hdsn3Sfcr6ksahFpPgb2D8`
  Add hmac-sha1 to sshd_config (required by go ssh lib)

* '3Yu.JSS0rB0oV6Gt3QnFfxaxvRju71bQ'
  lock down sshd_config permissions
  disable weak ssh ciphers
  disable weak ssh MACs

* `lUG9hrPUDugWx4Sv5vuKiN1X2Z1.lN.8`
  Adds kernel flags to enable console output in openstack environments

* `.EqtRtHJyHTr3hg4nFPq5QmJ4UxQ2WU.`
  upgrade linux kernel to 3.13.0-45

* `ISA4tKjaoq4koVay5rAzNZlzX7X0KafH`
  patch GNU libc to resolve CVE-2015-0235, "GHOST"

* `aoUtngdallpd2f6HhMxCveFvk6t6B2Ru`
  upgrade openssl to 1.0.1e-30.el6_6.5

* `Hb884_xVvhoIhdTEmMtaTHKC.s7b9AmN`
  switch logrotate to rotate based on size

* `xbBfE2GA7AgmCGA6MfNfhHX67vkJlIze`
  start monit during agent bootstrap

* `PB2C5YnPG.zZ5MgjBR96Y40UDpqVQb_D`
  disable reverse DNS resolution for sshd

* `6mBEQ5Gt5O6NJIFZxlyrf_05i.6s0OWF`
  CentOS 6.6
