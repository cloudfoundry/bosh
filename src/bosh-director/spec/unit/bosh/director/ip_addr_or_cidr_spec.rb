require 'spec_helper'

module Bosh::Director
  RSpec.describe IpAddrOrCidr do
    subject(:ip_addr_or_cidr) { IpAddrOrCidr.new(input) }

    describe '#initialize' do
      context 'when passed an instance of IpAddrOrCidr' do
        let(:input) { IpAddrOrCidr.new('10.10.10.10') }

        it 'succeeds' do
          expect(IpAddrOrCidr.new(input)).to eq(input)
        end
      end

      context 'when passed an instance of integer' do
        context 'less than or equal to 0xffffffff (IPv4 max int)' do
          let(:input) { IPAddr::IN4MASK }

          it 'creates an IPv4 address' do
            expect(IpAddrOrCidr.new(input)).to be_ipv4
          end
        end

        context 'greater than 0xffffffff (IPAddr::IN4MASK)' do
          let(:input) { IPAddr::IN4MASK + 1 }

          it 'creates an IPv6 address' do
            expect(IpAddrOrCidr.new(input)).to be_ipv6
          end
        end

        context 'greater than 0xffffffffffffffffffffffffffffffff (IPv6 max int)' do
          let(:input) { IPAddr::IN6MASK + 1 }

          it 'raises an exception' do
            expect { IpAddrOrCidr.new(input) }.to raise_error(IPAddr::InvalidAddressError)
          end
        end
      end
    end

    describe '#count' do
      context 'when initialized with a single IP' do
        context 'IPv4' do
          let(:input) { '192.168.0.1' }

          it 'returns 1' do
            expect(ip_addr_or_cidr.count).to eq(1)
          end
        end

        context 'IPv6' do
          let(:input) { '2001:0db8:85a3:0000:0000:8a2e:0370:7334' }

          it 'returns 1' do
            expect(ip_addr_or_cidr.count).to eq(1)
          end
        end
      end
    end

    describe '#to_s' do
      context 'IPv4' do
        let(:input) { '192.168.0.0/24' }

        it 'returns a string representing the IP' do
          expect(ip_addr_or_cidr.to_s).to eq(input)
        end
      end

      context 'IPv6' do
        let(:input) { 'fd00::/8' }

        it 'returns a string representing the IP' do
          expect(ip_addr_or_cidr.to_s).to eq(input)
        end
      end
    end

    describe '#to_i' do
      context 'IPv4' do
        let(:input) { '10.20.0.32' }

        it 'returns an integer representing the IP' do
          expect(ip_addr_or_cidr.to_i).to eq(169082912)
        end
      end

      context 'IPv6' do
        let(:input) { '2001:0db8:85a3:7334:8a2e:0000:0000:0000' }

        it 'returns an integer representing the IP' do
          expect(ip_addr_or_cidr.to_i).to eq(42540766452641698113073181315785818112)
        end
      end
    end

    describe '#base_addr' do
      context 'IPv4' do
        let(:input) { '10.20.0.32' }

        it 'returns a string representing the IP' do
          expect(ip_addr_or_cidr.base_addr).to eq(input)
        end
      end

      context 'IPv6' do
        let(:input) { '2001:db8:85a3:7334:8a2e::' }

        it 'returns a string representing the IP' do
          expect(ip_addr_or_cidr.base_addr).to eq(input)
        end
      end
    end

    describe '#to_s' do
      context 'IPv4' do
        let(:input) { '10.20.0.32/32' }

        it 'returns a string representing the IP' do
          expect(ip_addr_or_cidr.to_s).to eq(input)
        end
      end

      context 'IPv6' do
        let(:input) { '2001:db8:85a3:7334:8a2e::/128' }

        it 'returns a string representing the IP' do
          expect(ip_addr_or_cidr.to_s).to eq(input)
        end
      end
    end

    describe '#overlaps?' do
      context 'when two /32 IPs are the same' do
        it 'returns true' do
          a = IpAddrOrCidr.new('10.0.0.1')
          b = IpAddrOrCidr.new('10.0.0.1')
          expect(a.overlaps?(b)).to be true
        end
      end

      context 'when two /32 IPs are different' do
        it 'returns false' do
          a = IpAddrOrCidr.new('10.0.0.1')
          b = IpAddrOrCidr.new('10.0.0.2')
          expect(a.overlaps?(b)).to be false
        end
      end

      context 'when a /32 is inside a CIDR block' do
        it 'returns true (IP inside block)' do
          ip = IpAddrOrCidr.new('192.168.1.5')
          block = IpAddrOrCidr.new('192.168.1.0/25')
          expect(ip.overlaps?(block)).to be true
          expect(block.overlaps?(ip)).to be true
        end
      end

      context 'when a /32 is outside a CIDR block' do
        it 'returns false' do
          ip = IpAddrOrCidr.new('192.168.2.1')
          block = IpAddrOrCidr.new('192.168.1.0/25')
          expect(ip.overlaps?(block)).to be false
          expect(block.overlaps?(ip)).to be false
        end
      end

      context 'when two CIDR blocks overlap partially' do
        it 'returns true' do
          a = IpAddrOrCidr.new('192.168.1.0/30')
          b = IpAddrOrCidr.new('192.168.1.2/30')
          expect(a.overlaps?(b)).to be true
        end
      end

      context 'when two CIDR blocks are adjacent but non-overlapping' do
        it 'returns false' do
          a = IpAddrOrCidr.new('192.168.1.0/30')
          b = IpAddrOrCidr.new('192.168.1.4/30')
          expect(a.overlaps?(b)).to be false
          expect(b.overlaps?(a)).to be false
        end
      end

      context 'when a smaller block is nested inside a larger block' do
        it 'returns true' do
          outer = IpAddrOrCidr.new('10.0.0.0/24')
          inner = IpAddrOrCidr.new('10.0.0.128/25')
          expect(outer.overlaps?(inner)).to be true
          expect(inner.overlaps?(outer)).to be true
        end
      end

      context 'when CIDR blocks are completely disjoint' do
        it 'returns false' do
          a = IpAddrOrCidr.new('10.0.0.0/24')
          b = IpAddrOrCidr.new('10.0.1.0/24')
          expect(a.overlaps?(b)).to be false
        end
      end

      context 'with the exact scenario that triggers the IPAddr coercion bug' do
        it 'correctly detects overlap between /32 and /25' do
          ip32 = IpAddrOrCidr.new('192.168.1.0')
          block25 = IpAddrOrCidr.new('192.168.1.0/25')
          expect(ip32.overlaps?(block25)).to be true

          # A /32 NOT in the /25 range
          ip_outside = IpAddrOrCidr.new('192.168.1.200')
          expect(ip_outside.overlaps?(block25)).to be false
        end
      end

      context 'with IPv6 addresses' do
        it 'detects overlapping IPv6 ranges' do
          a = IpAddrOrCidr.new('fd00::/64')
          b = IpAddrOrCidr.new('fd00::1')
          expect(a.overlaps?(b)).to be true
          expect(b.overlaps?(a)).to be true
        end

        it 'returns false for non-overlapping IPv6 ranges' do
          a = IpAddrOrCidr.new('fd00::/64')
          b = IpAddrOrCidr.new('fd01::1')
          expect(a.overlaps?(b)).to be false
        end
      end
    end

    describe '#eql? and #hash' do
      context 'when two objects have the same base address and prefix' do
        it 'eql? returns true' do
          a = IpAddrOrCidr.new('10.0.11.32/30')
          b = IpAddrOrCidr.new('10.0.11.32/30')
          expect(a.eql?(b)).to be true
        end

        it 'hash values are equal' do
          a = IpAddrOrCidr.new('10.0.11.32/30')
          b = IpAddrOrCidr.new('10.0.11.32/30')
          expect(a.hash).to eq(b.hash)
        end

        it 'can be used as the same Set element' do
          a = IpAddrOrCidr.new('10.0.11.32/30')
          b = IpAddrOrCidr.new('10.0.11.32/30')
          expect(Set.new([a, b]).size).to eq(1)
        end
      end

      context 'when two objects have the same base address but different prefixes' do
        it 'eql? returns false' do
          a = IpAddrOrCidr.new('10.0.11.32/30')
          b = IpAddrOrCidr.new('10.0.11.32/32')
          expect(a.eql?(b)).to be false
        end

        it 'hash values are different' do
          a = IpAddrOrCidr.new('10.0.11.32/30')
          b = IpAddrOrCidr.new('10.0.11.32/32')
          expect(a.hash).not_to eq(b.hash)
        end

        it 'are stored as distinct elements in a Set' do
          a = IpAddrOrCidr.new('10.0.11.32/30')
          b = IpAddrOrCidr.new('10.0.11.32/32')
          expect(Set.new([a, b]).size).to eq(2)
        end
      end

      context 'when using objects with different base addresses' do
        it 'eql? returns false' do
          a = IpAddrOrCidr.new('10.0.11.32/30')
          b = IpAddrOrCidr.new('10.0.11.36/30')
          expect(a.eql?(b)).to be false
        end
      end

      context 'hash contract (eql? implies equal hash)' do
        it 'is satisfied for equal objects' do
          a = IpAddrOrCidr.new('192.168.1.0/24')
          b = IpAddrOrCidr.new('192.168.1.0/24')
          expect(a.eql?(b)).to be true
          expect(a.hash).to eq(b.hash)
        end

        it 'is satisfied for unequal objects (different prefix)' do
          a = IpAddrOrCidr.new('192.168.1.0/24')
          b = IpAddrOrCidr.new('192.168.1.0/32')
          expect(a.eql?(b)).to be false
        end
      end
    end
  end
end
