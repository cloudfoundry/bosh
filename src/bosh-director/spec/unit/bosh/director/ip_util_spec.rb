require 'spec_helper'

describe Bosh::Director::IpUtil do
  include Bosh::Director::IpUtil

  subject(:ip_util_includer) do
    Object.new.tap do|o|
      o.extend(Bosh::Director::IpUtil)
    end
  end

  describe 'each_ip' do
    context 'when expanding is turned on' do
      it 'should handle single ip' do
        counter = 0
        ip_util_includer.each_ip('1.2.3.4') do |ip|
          expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('1.2.3.4').to_i))
          counter += 1
        end
        expect(counter).to eq(1)
      end

      it 'should handle a range' do
        counter = 0
        ip_util_includer.each_ip('1.0.0.0/24') do |ip|
          expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('1.0.0.0').to_i + counter))
          counter += 1
        end
        expect(counter).to eq(256)
      end

      it 'should handle a differently formatted range' do
        counter = 0
        ip_util_includer.each_ip('1.0.0.0 - 1.0.1.0') do |ip|
          expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('1.0.0.0').to_i + counter))
          counter += 1
        end
        expect(counter).to eq(257)
      end
    end

    context 'when expanding is turned off' do
      it 'should handle a range' do
        counter = 0
        ip_util_includer.each_ip('1.0.0.0/24', false) do |ip|
          expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('1.0.0.0').to_i + counter))
          expect(ip.prefix).to eq(24)
          counter += 1
        end
        expect(counter).to eq(1)
      end

      it 'formats the ips to cidr blocks' do
        counter = 0
        ip_util_includer.each_ip('1.0.0.0 - 1.0.1.0', false) do |ip|
          if counter == 0
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new("1.0.0.0"))
            expect(ip.prefix).to eq(24)
          elsif counter == 1
              expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new("1.0.1.0"))
              expect(ip.prefix).to eq(32)
          else
            raise "Unexpected counter value: #{counter}"
          end

          counter += 1
        end
        expect(counter).to eq(2)
      end

      it 'formats the ips to cidr blocks' do
        counter = 0
        ip_util_includer.each_ip('1.0.0.5 - 1.0.0.98', false) do |ip|
          if counter == 0
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('1.0.0.5').to_i))
            expect(ip.prefix).to eq(32)
          elsif counter == 1
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('1.0.0.6').to_i))
            expect(ip.prefix).to eq(31)
          elsif counter == 2
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('1.0.0.8').to_i))
            expect(ip.prefix).to eq(29)
          elsif counter == 3
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('1.0.0.16').to_i))
            expect(ip.prefix).to eq(28)
          elsif counter == 4
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('1.0.0.32').to_i))
            expect(ip.prefix).to eq(27)
          elsif counter == 5
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('1.0.0.64').to_i))
            expect(ip.prefix).to eq(27)
          elsif counter == 6
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('1.0.0.96').to_i))
            expect(ip.prefix).to eq(31)
          elsif counter == 7
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('1.0.0.98').to_i))
            expect(ip.prefix).to eq(32)
          else
            raise "Unexpected counter value: #{counter}"
          end
          counter += 1

        end
        expect(counter).to eq(8)
      end

      it 'formats the ips to cidr blocks for ipv6' do
        counter = 0
        ip_util_includer.each_ip('2001:db8::5 - 2001:db8::e', false) do |ip|
          if counter == 0
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('2001:db8::5').to_i + counter))
            expect(ip.prefix).to eq(128)
          elsif counter == 1
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('2001:db8::6').to_i))
            expect(ip.prefix).to eq(127)
          elsif counter == 2
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('2001:db8::8').to_i))
            expect(ip.prefix).to eq(126)
          elsif counter == 3
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('2001:db8::c').to_i))
            expect(ip.prefix).to eq(127)
          elsif counter == 4
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('2001:db8::e').to_i))
            expect(ip.prefix).to eq(128)
          else
            raise "Unexpected counter value: #{counter}"
          end
          counter += 1

        end
        expect(counter).to eq(5)
      end

      it 'formats the ips to cidr blocks for ipv6' do
        counter = 0
        ip_util_includer.each_ip('2001:db8:: - 2001:db8::ff', false) do |ip|
          if counter == 0
            expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('2001:db8::').to_i))
            expect(ip.prefix).to eq(120)
          else
            raise "Unexpected counter value: #{counter}"
          end
          counter += 1

        end
        expect(counter).to eq(1)
      end
    end

    it 'should not accept invalid input' do
      expect { ip_util_includer.each_ip('1.2.4') }.to raise_error(Bosh::Director::NetworkInvalidIpRangeFormat, /Invalid IP or CIDR format/)
    end

    it 'should ignore nil values' do
      counter = 0
      ip_util_includer.each_ip(nil) do |ip|
        expect(ip).to eq(Bosh::Director::IpAddrOrCidr.new(IPAddr.new('1.2.3.4').to_i))
        counter += 1
      end
      expect(counter).to eq(0)
    end

    context 'when given invalid IP format' do
      it 'should raise NetworkInvalidIpRangeFormat error when given invalid IP range format' do
        range = '192.168.1.2-192.168.1.20,192.168.1.30-192.168.1.40'
        expect { ip_util_includer.each_ip(range) }.to raise_error Bosh::Director::NetworkInvalidIpRangeFormat,
                                                      "Invalid IP range format: #{range}"
      end

      it 'should raise Bosh::Director::NetworkInvalidIpRangeFormat' do
        range = '192.168.1.1-192.168.1.1/25'
        expect { ip_util_includer.each_ip(range) }.to raise_error Bosh::Director::NetworkInvalidIpRangeFormat,
                                                         "Invalid IP range format: #{range}"
      end
    end
  end

  describe 'base_addr' do
    it 'converts integer to CIDR IP' do
      expect(ip_util_includer.base_addr(168427582)).to eq('10.10.0.62')
    end
  end

  describe 'ip_address?' do
    it 'verifies ip address' do
      expect(ip_util_includer.ip_address?('127.0.0.1')).to eq(true)
      expect(ip_util_includer.ip_address?('2001:0db8:85a3:0000:0000:8a2e:0370:7334')).to eq(true)

      expect(ip_util_includer.ip_address?('2001:0db8:85a3:0000:0000:8a2e:0370:7334 ')).to eq(false)
      expect(ip_util_includer.ip_address?('255.255.255.256')).to eq(false)
      expect(ip_util_includer.ip_address?('999.999.999.999')).to eq(false)
      expect(ip_util_includer.ip_address?('dns.com')).to eq(false)
    end
  end
end
