require 'spec_helper'
require 'nerve/reporter/zookeeper_exhibitor'

describe Nerve::Reporter::ZookeeperExhibitor do
  let(:subject) { {
      'exhibitor_url' => 'http://localhost:8080/exhibitor/v1/cluster/list',
      'zk_path' => 'zk_path',
      'instance_id' => 'instance_id',
      'host' => 'host',
      'port' => 'port'
    }
  }
  it 'actually constructs an instance', :vcr do
    expect(Nerve::Reporter::ZookeeperExhibitor.new(subject).is_a?(Nerve::Reporter::ZookeeperExhibitor)).to be_truthy
  end

  it 'deregisters service on exit', :vcr do
    zk = double("zk")
    allow(zk).to receive(:close!)
    expect(zk).to receive(:create) { "full_path" }
    expect(zk).to receive(:delete).with("full_path", anything())

    allow(ZK).to receive(:new).and_return(zk)

    reporter = Nerve::Reporter::ZookeeperExhibitor.new(subject)
    reporter.start
    reporter.report_up
    reporter.stop
  end
end
