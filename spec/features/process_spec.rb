require 'spec_helper'

describe Nerve::Process do

  let(:command) { 'echo' }
  let(:options) { { :arguments => ['blah'] } }
  let(:process) { Nerve::Process.new(command, options) }

  describe '#start' do

    it "should start a process" do
      process.start
      process.wait
    end

  end

  describe '#stop' do

    it "should stop a process" do
      process.start
      process.stop
    end

    it "should return the status" do
      process.start
      process.stop.should be_an_instance_of Process::Status
    end

  end

  describe '#status' do

    it "should report the exit status" do
      process.start
      process.wait

      process.status.should be_an_instance_of Process::Status
      process.status.should == 0
    end

  end

  describe '#stdout' do

    let(:options) { { :arguments => ['from_stdout'] } }

    it "should have data from stdout" do
      process.start
      process.wait
      process.stdout.should == "from_stdout\n"
    end

  end

  describe '#environment' do

    let(:command) { 'env' }
    let(:options) { { :environment => { 'TEST' => 'blah' } } }

    it "should make it to the process" do
      process.start
      process.wait
      process.stdout.lines.map(&:strip).to_a.should include 'TEST=blah'
    end

  end

end

describe Nerve::NerveProcess do

  let(:process) { Nerve::NerveProcess.new }

  it "should start nerve" do
    process.start
    until_timeout(30) { raise unless process.up? }
  end

end

describe Nerve::ZooKeeperProcess do

  let(:process) { Nerve::ZooKeeperProcess.new }

  it "should start zookeeper" do
    process.start
    until_timeout(30) { raise unless process.up? }
  end

end
