require 'spec_helper'

describe Nerve::Test::Process do

  let(:command) { 'echo' }
  let(:options) { { :arguments => ['blah'] } }
  let(:process) { Nerve::Test::Process.new(command, options) }

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

end

describe Nerve::Test::NerveProcess do

  let(:process) { Nerve::Test::NerveProcess.new }

  it "should start nerve" do
    process.start
    process.wait

    puts process.stderr
  end

end

describe Nerve::Test::ZooKeeperProcess do

  let(:process) { Nerve::Test::ZooKeeperProcess.new }

  it "should start zookeeper" do
    process.start
  end

end
