require 'spec_helper'
require 'nerve/reporter/zookeeper'
require 'zookeeper'

describe Nerve::Reporter::Zookeeper do
  let(:subject) { {
      'zk_hosts' => ['zkhost1', 'zkhost2'],
      'zk_path' => 'zk_path',
      'instance_id' => 'instance_id',
      'host' => 'host',
      'port' => 'port'
    }
  }

  let(:zk) { double("zk") }

  it 'actually constructs an instance' do
    expect(Nerve::Reporter::Zookeeper.new(subject).is_a?(Nerve::Reporter::Zookeeper)).to eql(true)
  end

  it 'deregisters service on exit' do
    allow(zk).to receive(:close!)
    allow(zk).to receive(:connected?).and_return(true)
    expect(zk).to receive(:exists?) { "zk_path" }.and_return(false)
    expect(zk).to receive(:mkdir_p) { "zk_path" }
    expect(zk).to receive(:create) { "full_path" }
    expect(zk).to receive(:delete).with("full_path", anything())

    allow(ZK).to receive(:new).and_return(zk)

    reporter = Nerve::Reporter::Zookeeper.new(subject)
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
      @reporter = Nerve::Reporter::Zookeeper.new(subject)
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

      it 'swallows zk connetion errors and returns false on report_up' do
        # this condition is triggered if connection is shortly interrupted
        # so connected? still return true
        expect(zk).to receive(:set).and_raise(ZK::Exceptions::OperationTimeOut)
        expect(@reporter.report_up).to be false
      end

      it 'swallows zk connetion errors and returns false on report_down' do
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
      service = subject.merge({'node_type' => 'ephemeral'})
      reporter = Nerve::Reporter::Zookeeper.new(service)
      expect(reporter.instance_variable_get(:@mode)).to be_kind_of(Symbol)
      expect(reporter.instance_variable_get(:@mode)).to eq(:ephemeral)
    end

    it 'default type of node is :ephemeral_sequential' do
      reporter = Nerve::Reporter::Zookeeper.new(subject)
      expect(reporter.instance_variable_get(:@mode)).to eq(:ephemeral_sequential)
    end
  end
end

