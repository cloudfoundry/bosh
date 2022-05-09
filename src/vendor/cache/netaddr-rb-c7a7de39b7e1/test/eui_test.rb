#!/usr/bin/ruby

require_relative "../lib/netaddr.rb"
require 'test/unit'



class TestEUI < Test::Unit::TestCase

    def test_new
        assert_not_nil(NetAddr::EUI48.new('aabbccddeeff') )
        assert_not_nil(NetAddr::EUI48.new('aabbccddeeff') )
        assert_not_nil(NetAddr::EUI64.new('aabbccddeeff0001') )
        assert_not_nil(NetAddr::EUI48.new(0x000000000001) )
        assert_not_nil(NetAddr::EUI64.new(0x0000000000000001) )

        assert_raise(ArgumentError){ NetAddr::EUI48.new() }
        assert_raise(ArgumentError){ NetAddr::EUI48.new({}) }
        assert_raise(ArgumentError){ NetAddr::EUI64.new() }
        assert_raise(ArgumentError){ NetAddr::EUI64.new({}) }
    end

    def test_create
        assert_not_nil(NetAddr::EUI.create('aa-bb-cc-dd-ee-ff') )
        assert_not_nil(NetAddr::EUI.create('aa:bb:cc:dd:ee:ff') )
        assert_not_nil(NetAddr::EUI.create('aabb.ccdd.eeff') )
        assert_not_nil(NetAddr::EUI.create('aa-bb-cc-dd-ee-ff-00-01') )

        assert_raise(ArgumentError){ NetAddr::EUI.create() }
        assert_raise(ArgumentError){ NetAddr::EUI.create(0x0000000000000001) }

        assert_kind_of(NetAddr::EUI48, NetAddr::EUI.create('aa-bb-cc-dd-ee-ff'))
        assert_kind_of(NetAddr::EUI64, NetAddr::EUI.create('aa-bb-cc-dd-ee-ff-00-01'))
    end

    def test_simple
        mac = NetAddr::EUI.create('aa-bb-cc-dd-ee-ff')
        assert_raise(ArgumentError) {mac.oui(:test => true)}
        assert_raise(ArgumentError) {mac.ei(:test => true)}

        assert_equal('aa-bb-cc', mac.oui )
        assert_equal('dd-ee-ff', mac.ei )
        assert_equal('aa:bb:cc', mac.oui(:Delimiter => ':' ) )
        assert_equal('dd:ee:ff', mac.ei(:Delimiter => ':' )  )
        assert_equal('aa-bb-cc-dd-ee-ff', mac.address )
        assert_equal('aa:bb:cc:dd:ee:ff', mac.address(:Delimiter => ':') )
        assert_equal('aabb.ccdd.eeff', mac.address(:Delimiter => '.') )
        assert_equal(0xaabbccddeeff, mac.to_i )
        assert_equal(NetAddr::EUI48, mac.class )

        mac = NetAddr::EUI.create('aa-bb-cc-dd-ee-ff-01-02')
        assert_raise(ArgumentError) {mac.oui(:test => true)}
        assert_raise(ArgumentError) {mac.ei(:test => true)}
        assert_equal('aa-bb-cc', mac.oui )
        assert_equal('dd-ee-ff-01-02', mac.ei )
        assert_equal('aa:bb:cc', mac.oui(:Delimiter => ':') )
        assert_equal('dd:ee:ff:01:02', mac.ei(:Delimiter => ':' ) )
        assert_equal('aa-bb-cc-dd-ee-ff-01-02', mac.address )
        assert_equal('aa:bb:cc:dd:ee:ff:01:02', mac.address(:Delimiter => ':') )
        assert_equal('aabb.ccdd.eeff.0102', mac.address(:Delimiter => '.') )
        assert_equal(0xaabbccddeeff0102, mac.to_i )
        assert_equal(NetAddr::EUI64, mac.class )

    end

    def test_link_local
        mac = NetAddr::EUI.create('aa-bb-cc-dd-ee-ff')
        assert_equal('fe80:0000:0000:0000:a8bb:ccff:fedd:eeff', mac.link_local )

        mac = NetAddr::EUI.create('1234.5678.9abc')
        assert_equal('fe80:0000:0000:0000:1034:56ff:fe78:9abc', mac.link_local )

        mac = NetAddr::EUI.create('1234.5678.9abc.def0')
        assert_equal('fe80:0000:0000:0000:1034:5678:9abc:def0', mac.link_local(:Objectify => true).ip )
        assert_raise(ArgumentError) {mac.link_local(:test => true)}
    end

    def test_to_eui64
        mac = NetAddr::EUI.create('aa-bb-cc-dd-ee-ff')
        assert_equal('aa-bb-cc-ff-fe-dd-ee-ff', mac.to_eui64.address )

        # check that to_eui64 has no side effects
        b = mac.to_eui64
        c = mac.to_eui64
        assert_equal(b.to_s, c.to_s)
    end

    def test_to_ipv6
        mac = NetAddr::EUI.create('aa-bb-cc-dd-ee-ff')
        assert_equal('fe80:0000:0000:0000:a8bb:ccff:fedd:eeff', mac.to_ipv6('fe80::/64') )

        mac = NetAddr::EUI.create('1234.5678.9abc')
        assert_equal('fe80:0000:0000:0000:1034:56ff:fe78:9abc', mac.to_ipv6('fe80::/64') )

        mac = NetAddr::EUI.create('1234.5678.9abc.def0')
        assert_equal('fe80:0000:0000:0000:1034:5678:9abc:def0', mac.to_ipv6('fe80::/64', :Objectify => true).ip )
        assert_raise(ArgumentError) {mac.link_local(:test => true)}
        assert_raise(NetAddr::ValidationError) {mac.to_ipv6('fe80::/65')}
    end

end
