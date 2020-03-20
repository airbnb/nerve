require 'spec_helper'
require 'nerve/reporter/zookeeper'
require 'zookeeper'
require 'active_support/all'
require 'active_support/testing/time_helpers'

describe Nerve::Reporter::Zookeeper do
  include ActiveSupport::Testing::TimeHelpers

  let(:base_config) { {
      'zk_hosts' => ['zkhost1', 'zkhost2'],
      'zk_path' => 'zk_path',
      'instance_id' => 'instance_id',
      'host' => 'host',
      'port' => 'port'
    }
  }

  let(:config) { base_config }

  subject { Nerve::Reporter::Zookeeper.new(config) }

  let(:zk) { double("zk") }

  before :each do
    Nerve::Reporter::Zookeeper.class_variable_set(:@@zk_pool, {})

    pool_count = {}
    allow(pool_count).to receive(:[]).and_return(1)
    Nerve::Reporter::Zookeeper.class_variable_set(:@@zk_pool_count, pool_count)
  end

  it 'actually constructs an instance' do
    expect(subject.is_a?(Nerve::Reporter::Zookeeper)).to eql(true)
  end

  it 'deregisters service on exit' do
    allow(zk).to receive(:close!)
    allow(zk).to receive(:connected?).and_return(true)
    expect(zk).to receive(:exists?) { "zk_path" }.and_return(false)
    expect(zk).to receive(:mkdir_p) { "zk_path" }
    expect(zk).to receive(:create) { "full_path" }
    expect(zk).to receive(:delete).with("full_path", anything())

    allow(ZK).to receive(:new).and_return(zk)

    reporter = Nerve::Reporter::Zookeeper.new(config)
    reporter.start
    reporter.report_up
    reporter.stop
  end

  context "when reporter is up" do
    before(:each) do
      allow(zk).to receive(:close!)
      allow(zk).to receive(:connected?).and_return(true)
      allow(zk).to receive(:exists?) { "zk_path" }.and_return(false)
      allow(zk).to receive(:mkdir_p) { "zk_path" }
      allow(zk).to receive(:create) { "full_path" }
      allow(zk).to receive(:set) { "full_path" }
      allow(zk).to receive(:delete).with("full_path", anything())
      allow(ZK).to receive(:new).and_return(zk)
      @reporter = Nerve::Reporter::Zookeeper.new(config)
      @reporter.start
    end

    after(:each) do
      # reset the class variable to avoid mock object zk leak
      Nerve::Reporter::Zookeeper.class_variable_set(:@@zk_pool, {})
      Nerve::Reporter::Zookeeper.class_variable_set(:@@zk_pool_count, {})
    end

    it "returns true on report_up" do
      expect(@reporter.report_up).to be true
    end

    it "returns true on report_down" do
      @reporter.report_up
      expect(@reporter.report_down).to be true
    end

    it "returns true on ping?" do
      @reporter.report_up

      expect(zk).to receive(:exists?) { "zk_path" }.and_return(true)
      expect(@reporter.ping?).to be true
    end

    context "when zk.connected? started to return false" do
      before(:each) do
        @reporter.report_up
        # this condition is triggered if connection has been lost for a while (a few sec)
        expect(zk).to receive(:connected?).and_return(false)
      end

      it 'returns false on ping?' do
        expect(zk).not_to receive(:exists?)
        expect(@reporter.ping?).to be false
      end

      it 'returns false on report_up without zk operation' do
        expect(zk).not_to receive(:set)
        expect(@reporter.report_up).to be false
      end

      it 'returns false on report_up without zk operation' do
        expect(zk).not_to receive(:delete)
        expect(@reporter.report_down).to be false
      end
    end

    context "when there is a short disconnection" do
      before(:each) do
        @reporter.report_up
      end

      it 'returns false on ping?' do
        # this condition is triggered if connection is shortly interrupted
        # so connected? still return true
        expect(zk).to receive(:exists?).and_raise(ZK::Exceptions::OperationTimeOut)
        expect(@reporter.ping?).to be false
      end

      it 'swallows zk connection errors and returns false on report_up' do
        # this condition is triggered if connection is shortly interrupted
        # so connected? still return true
        expect(zk).to receive(:set).and_raise(ZK::Exceptions::OperationTimeOut)
        expect(@reporter.report_up).to be false
      end

      it 'swallows zk connection errors and returns false on report_down' do
        # this condition is triggered if connection is shortly interrupted
        # so connected? still return true
        expect(zk).to receive(:delete).and_raise(ZK::Exceptions::OperationTimeOut)
        expect(@reporter.report_down).to be false
      end

      it 'swallows zookeeper not connected errors and returns false on report_up' do
        # this condition is triggered if connection is shortly interrupted
        # so connected? still return true
        expect(zk).to receive(:set).and_raise(::Zookeeper::Exceptions::NotConnected)
        expect(@reporter.report_up).to be false
      end

      it 'swallows zookeeper not connected errors and returns false on report_down' do
        # this condition is triggered if connection is shortly interrupted
        # so connected? still return true
        expect(zk).to receive(:delete).and_raise(::Zookeeper::Exceptions::NotConnected)
        expect(@reporter.report_down).to be false
      end

    end

    context "when there is other ZK errors" do
      before(:each) do
        @reporter.report_up
      end

      it 'raises zk non-connection error on ping?' do
        # this condition is triggered if connection is shortly interrupted
        # so connected? still return true
        expect(zk).to receive(:exists?).and_raise(ZK::Exceptions::SessionExpired)
        expect {@reporter.ping?}.to raise_error(ZK::Exceptions::SessionExpired)
      end

      it 'raises zk non-connetion errors on report_up' do
        # this condition is triggered if connection is shortly interrupted
        # so connected? still return true
        expect(zk).to receive(:set).and_raise(ZK::Exceptions::SessionExpired)
        expect {@reporter.report_up}.to raise_error(ZK::Exceptions::SessionExpired)
      end

      it 'raises zk non-connetion errors on report_down' do
        # this condition is triggered if connection is shortly interrupted
        # so connected? still return true
        expect(zk).to receive(:delete).and_raise(ZK::Exceptions::SessionExpired)
        expect {@reporter.report_down}.to raise_error(ZK::Exceptions::SessionExpired)
      end
    end

    context "when reporter up with setting ZK node type" do

      it 'ZK client should use the default node type as :ephemeral_sequential if not specified' do
        expect(zk).to receive(:create).with(anything, {:data => "{\"host\":\"host\",\"port\":\"port\",\"name\":\"instance_id\"}", :mode => :ephemeral_sequential})
        expect(@reporter.report_up).to be true
      end

      it 'ZK client should use the node type as specified' do
        @reporter.instance_variable_set(:@mode, :persistent)

        expect(zk).to receive(:create).with(anything, {:data => "{\"host\":\"host\",\"port\":\"port\",\"name\":\"instance_id\"}", :mode => :persistent})
        expect(@reporter.report_up).to be true

        @reporter.instance_variable_set(:@mode, nil)
      end
    end
  end

  context "reporter path encoding" do
    it 'encode child name with optional fields' do
      service = {
        'instance_id' => 'i-xxxxxx',
        'host' => '127.0.0.1',
        'port' => 3000,
        'labels' => {
          'region' => 'us-east-1',
          'az' => 'us-east-1a'
        },
        'zk_hosts' => ['zkhost1', 'zkhost2'],
        'zk_path' => 'zk_path',
        'use_path_encoding' => true,
      }
      expected = {
        'name' => 'i-xxxxxx',
        'host' => '127.0.0.1',
        'port' => 3000,
        'labels' => {
          'region' => 'us-east-1',
          'az' => 'us-east-1a'
        }
      }
      reporter = Nerve::Reporter::Zookeeper.new(service)
      str = reporter.send(:encode_child_name, service)
      JSON.parse(Base64.urlsafe_decode64(str[12...-1])).should == expected
    end

    it 'encode child name with required fields only' do
      service = {
        'instance_id' => 'i-xxxxxx',
        'use_path_encoding' => true,
        'host' => '127.0.0.1',
        'port' => 3000,
        'zk_hosts' => ['zkhost1', 'zkhost2'],
        'zk_path' => 'zk_path',
        'use_path_encoding' => true,
      }
      expected = {
        'name' => 'i-xxxxxx',
        'host' => '127.0.0.1',
        'port' => 3000
      }
      reporter = Nerve::Reporter::Zookeeper.new(service)
      str = reporter.send(:encode_child_name, service)
      JSON.parse(Base64.urlsafe_decode64(str[11...-1])).should == expected
    end

    it 'encode child name without path encoding' do
      service = {
        'instance_id' => 'i-xxxxxx',
        'host' => '127.0.0.1',
        'port' => 3000,
        'zk_hosts' => ['zkhost1', 'zkhost2'],
        'zk_path' => 'zk_path',
      }
      reporter = Nerve::Reporter::Zookeeper.new(service)
      expect(reporter.send(:encode_child_name, service)).to eq('/i-xxxxxx_')
    end
  end

  context 'parse node type properly when reporter is initializing' do
    it 'node type should be converted to symbol' do
      service = config.merge({'node_type' => 'ephemeral'})
      reporter = Nerve::Reporter::Zookeeper.new(service)
      expect(reporter.instance_variable_get(:@mode)).to be_kind_of(Symbol)
      expect(reporter.instance_variable_get(:@mode)).to eq(:ephemeral)
    end

    it 'default type of node is :ephemeral_sequential' do
      reporter = Nerve::Reporter::Zookeeper.new(config)
      expect(reporter.instance_variable_get(:@mode)).to eq(:ephemeral_sequential)
    end
  end

  describe '#report_up' do
    let(:parent_path) { '/test' }
    let(:path) { "#{parent_path}/child" }
    let(:key_prefix) { path }
    let(:mode) { 'persistent' }
    let(:data) { {'host' => 'i-test', 'test' => true} }


    context 'when node already exists' do
      before :each do
        subject.instance_variable_set(:@zk, zk)
        subject.instance_variable_set(:@zk_path, parent_path)
        subject.instance_variable_set(:@key_prefix, path)
        subject.instance_variable_set(:@data, data)
        subject.instance_variable_set(:@mode, mode.to_sym)

        allow(zk).to receive(:connected?).and_return(true)
        allow(zk).to receive(:exists?).with(parent_path).and_return(true)
        allow(zk).to receive(:mkdir_p).with(parent_path)
        allow(zk)
          .to receive(:create)
          .with(path, :data => data, :mode => mode.to_sym)
          .and_raise(ZK::Exceptions::NodeExists)
      end

      context 'with persistent nodes' do
        it 'calls set' do
          expect(zk).to receive(:set).with(path, data).exactly(:once)
          expect { subject.report_up }.not_to raise_error
        end
      end

      context 'with persistent sequential nodes' do
        let(:mode) { 'persistent_sequential' }

        it 'calls set' do
          expect(zk).to receive(:set).with(path, data).exactly(:once)
          expect { subject.report_up }.not_to raise_error
        end
      end

      context 'with ephemeral nodes' do
        let(:mode) { 'ephemeral' }
        it 'calls set' do
          expect(zk).to receive(:set).with(path, data).exactly(:once)
          expect { subject.report_up }.not_to raise_error
        end
      end

      context 'with ephemeral sequential nodes' do
        let(:mode) { 'ephemeral_sequential' }

        it 'calls set' do
          expect(zk).to receive(:set).with(path, data).exactly(:once)
          expect { subject.report_up }.not_to raise_error
        end
      end
    end
  end

  describe '#ping?' do
    let(:path) { '/test/path' }
    let(:data) { {'host' => 'i-test', 'test' => true} }
    let(:zk_connected) { true }
    let(:node_exists) { true }

    before :each do
      subject.instance_variable_set(:@zk, zk)
      subject.instance_variable_set(:@data, data)
      subject.instance_variable_get(:@full_key).set(path) if node_exists
      allow(zk).to receive(:exists?).and_return(node_exists)
      allow(zk).to receive(:connected?).and_return(zk_connected)
    end

    it 'calls stat on zookeeper' do
      expect(zk).to receive(:exists?).exactly(:once)
      subject.ping?
    end

    context 'when zk exists returns false' do
      let(:node_exists) { false }

      it 'returns false' do
        expect(subject.ping?).to eq(false)
      end
    end

    context 'when zk exists returns true' do
      let(:node_exists) { true }

      it 'returns true' do
        expect(subject.ping?).to eq(true)
      end
    end

    context 'when disconnected from zookeeper' do
      let(:zk_connected) { false }

      it 'returns false' do
        expect(subject.ping?).to be(false)
      end
    end
  end

  describe '#start_ttl_renew_thread' do
    let(:config) {
      base_config.merge({'zk_path' => parent_path,
                         'ttl_seconds' => ttl,
                         'node_type' => node_type})
    }
    let(:ttl) { 360 }
    let(:parent_path) { '/test' }
    let(:node_type) { 'persistent' }

    before :each do
      subject.instance_variable_set(:@zk, zk)
      allow(zk).to receive(:connected?).and_return(true)
      allow(zk).to receive(:exists?).with(parent_path).and_return(true)
    end

    it 'starts a thread' do
      expect(Thread).to receive(:new).exactly(:once)
      subject.send(:start_ttl_renew_thread)
    end

    context 'when TTL mode is disabled' do
      let(:ttl) { nil }

      it 'does not start a thread' do
        expect(Thread).not_to receive(:new)
        subject.send(:start_ttl_renew_thread)
      end

      context 'when writing ephemeral nodes' do
        let(:node_type) { 'ephemeral_sequential' }

        it 'does not start a thread' do
          expect(Thread).not_to receive(:new)
          subject.send(:start_ttl_renew_thread)
        end
      end
    end
  end

  describe '#stop_ttl_renew_thread' do
    let(:thread) { double(Thread) }
    let(:config) { base_config.merge({'ttl_seconds' => 10, 'node_type' => 'persistent'}) }

    before :each do
      allow(Thread).to receive(:new).and_return(thread)
      subject.send(:start_ttl_renew_thread)
    end

    it 'waits on the thread' do
      expect(thread).to receive(:join).exactly(:once)
      subject.send(:stop_ttl_renew_thread)
    end

    context 'when thread is not started' do
      let(:thread) { nil }

      it 'continues silently' do
        expect(thread).not_to receive(:join)
        expect { subject.send(:stop_ttl_renew_thread) }.not_to raise_error
      end
    end
  end

  describe '#renew_ttl' do
    let(:config) {
      base_config.merge({'zk_path' => parent_path,
                         'ttl_seconds' => ttl,
                         'node_type' => node_type})
    }
    let(:ttl) { 360 }
    let(:parent_path) { '/test' }
    let(:path) { "#{parent_path}/child" }
    let(:data) { {'host' => 'i-test', 'test' => true} }
    let(:node_type) { 'persistent' }
    let(:now) {
      travel_to Time.now
      # The returned value needs to occur *after* the call to travel_to, because
      # travel_to will round the current Time to a certain precision.
      # Thus, we need to obtain the rounded time.
      # See: https://api.rubyonrails.org/v5.2.4.1/classes/ActiveSupport/Testing/TimeHelpers.html#method-i-travel_to
      Time.now
    }

    before :each do
      subject.instance_variable_set(:@zk, zk)
      subject.instance_variable_get(:@full_key).set(path)
      subject.instance_variable_set(:@key_prefix, path)
      subject.instance_variable_set(:@data, data)
    end

    context 'when last TTL has expired' do
      let(:last_refresh) { now - ttl - 1 }

      it 'calls zk.set' do
        expect(zk).to receive(:set).with(path, data).exactly(:once)
        subject.send(:renew_ttl, last_refresh)
      end

      it 'returns new time' do
        allow(zk).to receive(:set)
        expect(subject.send(:renew_ttl, last_refresh)).to eq(now)
      end

      context 'when path is not set' do
        let(:path) { nil }

        it 'continues silently' do
          expect { subject.send(:renew_ttl, last_refresh) }.not_to raise_error
        end

        it 'returns now' do
          expect(subject.send(:renew_ttl, last_refresh)).to eq(now)
        end
      end

      context 'when node does not exist from Zookeeper' do
        before :each do
          allow(zk).to receive(:set).and_raise(Zookeeper::Exceptions::NoNode)
        end

        it 'continues silently' do
          expect { subject.send(:renew_ttl, last_refresh) }.not_to raise_error
        end

        it 'returns now' do
          expect(subject.send(:renew_ttl, last_refresh)).to eq(now)
        end
      end

      context 'when Zookeeper takes a long time to respond' do
        before :each do
          allow(zk).to receive(:set) {
            # response takes 5s
            travel 5
          }
        end

        it 'returns new time' do
          expect(subject.send(:renew_ttl, last_refresh)).to eq(now + 5)
        end
      end

      context 'when Zookeeper times out' do
        before :each do
          allow(zk).to receive(:set).and_raise(ZK::Exceptions::OperationTimeOut)
        end

        it 'ignores the error' do
          expect { subject.send(:renew_ttl, last_refresh) }.not_to raise_error
        end
      end

      context 'when Zookeeper has connection issues' do
        before :each do
          allow(zk).to receive(:set).and_raise(ZK::Exceptions::ConnectionLoss)
        end

        it 'ignores the error' do
          expect { subject.send(:renew_ttl, last_refresh) }.not_to raise_error
        end
      end
    end

    context 'when last TTL is active' do
      let(:last_refresh) { now - ttl + 1 }

      it 'does not call zk.set' do
        expect(zk).not_to receive(:set)
        subject.send(:renew_ttl, last_refresh)
      end

      it 'returns old time' do
        allow(zk).to receive(:set)
        expect(subject.send(:renew_ttl, last_refresh)).to eq(last_refresh)
      end

      context 'when path is not set' do
        let(:path) { nil }

        it 'continues silently' do
          expect { subject.send(:renew_ttl, last_refresh) }.not_to raise_error
        end

        it 'returns old time' do
          expect(subject.send(:renew_ttl, last_refresh)).to eq(last_refresh)
        end
      end

      context 'when node does not exist from Zookeeper' do
        before :each do
          allow(zk).to receive(:set).and_raise(Zookeeper::Exceptions::NoNode)
        end

        it 'continues silently' do
          expect { subject.send(:renew_ttl, last_refresh) }.not_to raise_error
        end

        it 'returns old time' do
          expect(subject.send(:renew_ttl, last_refresh)).to eq(last_refresh)
        end
      end
    end
  end
end

