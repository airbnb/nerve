require 'spec_helper'
require 'nerve/reporter/zookeeper'

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

  context "when reporter has been up and there is connection issue" do
    before(:each) do
      allow(zk).to receive(:close!)
      allow(zk).to receive(:connected?).and_return(true)
      expect(zk).to receive(:exists?) { "zk_path" }.and_return(false)
      expect(zk).to receive(:mkdir_p) { "zk_path" }
      expect(zk).to receive(:create) { "full_path" }
      allow(ZK).to receive(:new).and_return(zk)

      @reporter = Nerve::Reporter::Zookeeper.new(subject)
      @reporter.start
      @reporter.report_up
    end

    after(:each) do
      # reset the class variable to avoid mock object zk leak
      Nerve::Reporter::Zookeeper.class_variable_set(:@@zk_pool, {})
      Nerve::Reporter::Zookeeper.class_variable_set(:@@zk_pool_count, {})
    end

    it 'returns false on ping? when zk is disconnected' do
      # this condition is triggered if connection has been lost for a while (a few sec)
      expect(zk).to receive(:connected?).and_return(false)
      expect(zk).not_to receive(:exists?)
      expect(@reporter.ping?).to be false
    end

    it 'returns false on ping? when zk.exists? check failed due to connection loss' do
      # this condition is triggered if connection is shortly interrupted
      # so connected? still return true
      expect(zk).to receive(:connected?).and_return(true)
      expect(zk).to receive(:exists?).and_raise(ZK::Exceptions::OperationTimeOut)

      expect(@reporter.ping?).to be false
    end

    it 'raises zk non-connection error on ping? when zk.exists? check fail' do
      # this condition is triggered if connection is shortly interrupted
      # so connected? still return true
      expect(zk).to receive(:connected?).and_return(true)
      expect(zk).to receive(:exists?).and_raise(ZK::Exceptions::SessionExpired)

      expect {@reporter.ping?}.to raise_error(ZK::Exceptions::SessionExpired)
    end

    it 'does not do zk operation in report_up when connection has lost' do
      # this condition is triggered if connection has been lost for a while (a few sec)
      expect(zk).to receive(:connected?).and_return(false)
      expect(zk).not_to receive(:set)

      @reporter.report_up
    end

    it 'swallows zk connetion errors on report_up' do
      # this condition is triggered if connection is shortly interrupted
      # so connected? still return true
      expect(zk).to receive(:connected?).and_return(true)
      expect(zk).to receive(:set).and_raise(ZK::Exceptions::OperationTimeOut)

      expect {@reporter.report_up}.not_to raise_error
    end

    it 'raises zk non-connetion errors on report_up' do
      # this condition is triggered if connection is shortly interrupted
      # so connected? still return true
      expect(zk).to receive(:connected?).and_return(true)
      expect(zk).to receive(:set).and_raise(ZK::Exceptions::SessionExpired)

      expect {@reporter.report_up}.to raise_error(ZK::Exceptions::SessionExpired)
    end

    it 'does not do zk operation in report_down when connection has lost' do
      # this condition is triggered if connection has been lost for a while (a few sec)
      expect(zk).to receive(:connected?).and_return(false)
      expect(zk).not_to receive(:delete)

      @reporter.report_down
    end

    it 'swallows zk connetion errors on report_down' do
      # this condition is triggered if connection is shortly interrupted
      # so connected? still return true
      expect(zk).to receive(:connected?).and_return(true)
      expect(zk).to receive(:delete).and_raise(ZK::Exceptions::OperationTimeOut)

      expect {@reporter.report_down}.not_to raise_error
    end

    it 'raises zk non-connetion errors on report_down' do
      # this condition is triggered if connection is shortly interrupted
      # so connected? still return true
      expect(zk).to receive(:connected?).and_return(true)
      expect(zk).to receive(:delete).and_raise(ZK::Exceptions::SessionExpired)

      expect {@reporter.report_down}.to raise_error(ZK::Exceptions::SessionExpired)
    end
  end
end

