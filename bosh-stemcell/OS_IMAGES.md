# OS Image Changes

OS images are stored in S3 bucket [bosh-os-images](http://s3.amazonaws.com/bosh-os-images/).


## Ubuntu 14.04

Ubuntu 14.04 images have filename `bosh-ubuntu-trusty-os-image.tgz`

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

 * `PB2C5YnPG.zZ5MgjBR96Y40UDpqVQb_D`
  disable reverse DNS resolution for sshd

 * `6mBEQ5Gt5O6NJIFZxlyrf_05i.6s0OWF`
  CentOS 6.6

## CentOS 6.5

CentOS 6.5 images have filename `bosh-centos-6_5-os-image.tgz`

* `KVSJwBVkLQ.OKnVpgBiJILrcJr1E8IPK`
  upgrade openssl to 1.0.1e-30.el6_5.2

* `ORrEQRfUIO59WkVGbkBsv9jgGjU9KzBW`
  upgrade bash to 4.1.2-15.el6_5.2

* `qHA0KEgGnb7Tf8SAzJVnrKb9OcaXOurv`
  upgrade bash to 4.1.2-15.el6_5.1

* `GwV8gWhNVttyPdapUxh38tnYwZsrNbSc`
  chmod /home/vcap to 755

* `embHpGSvY3DXaOL8MFNA_a28B1yYG4pv`
  install parted

* `d085u3Knx4KtTOGmFmanfNHH_oY9Hd.n`
  using latest OpenSSL `1.0.1f`
  (23fe6fcd8518446cbdbec360c2f1e4b37834db88)

* `OTJRx3.keQXrSVMfXhvhRhwWH1wrbdvV`
  set timezone (UTC) and locale (UTF8)
  (1eecf11f5fb153effc44cc720ea4b232a620649f)

* `IFHfIgS_2fIP.U0cWMH7..afJjo4ysz0`
  upgraded OpenSSL to `1.0.1e-16.el6_5.7`

* `wFNFCug89mKKgjxVdpITswcfWVPETDUS`
  CentOS 6.5


## Ubuntu 10.04

Ubuntu 10.04 images have filename `bosh-ubuntu-lucid-os-image.tgz`

* `eZWOusvZfqLMPCxoh6ywHqEeVvkv6oRW`
  update libgcrypt11 to 1.4.4-5ubuntu2.3
  update gnupg to 1.4.10-2ubuntu1.7

* `6M6P12YoeRKtGB6QkRcAE02Cd1QrTfVN`
  update libc6 to 2.11.1-0ubuntu7.16

* `CK1gpiyNTC7ijICLm_xIKA9o2YHrlCU1`
  using latest libssl `0.9.8k-7ubuntu8.21`

* `L9pIPNIBLrq7zRcuh.8ufAseBvWfP.1d`
  using latest libssl `0.9.8k-7ubuntu8`

* `hGvKHxxg9bboL3e1Ldi27H746AsmEcRQ`
  Remove resolv.conf clearing from firstboot.sh
  (307d760b783454c96717a9b1036265783826a369)

* `IFBbp72WZyd3SHN.75RWZz.jWJeEU40s`
  using latest OpenSSL `1.0.1f`
  (23fe6fcd8518446cbdbec360c2f1e4b37834db88)

* `EGp_C9N3T0ctgdv0FJ44_AuF7MUlpA9G`
  using /sbin/rescan-scsi-bus to match Ubuntu 14.04
  (e448b0e8b0967288488c929fbbf953b22a046d1d)

* `r5606X8C8rS8dBlENBVEXoIaPVBVobXw`
  Ubuntu 10.04
