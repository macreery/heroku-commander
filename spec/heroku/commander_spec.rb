require 'spec_helper'

describe Heroku::Commander do
  context "without arguments" do
    subject do
      Heroku::Commander.new
    end
    its(:app) { should be_nil }
  end
  context "with app" do
    before :each do
      Heroku::Executor.stub(:run)
    end
    subject do
      Heroku::Commander.new({ :app => "heroku-commander" })
    end
    its(:app) { should eq "heroku-commander" }
    its(:config) { should be_a Heroku::Config }
  end
  context "with a heroku configuration" do
    before :each do
      Heroku::Executor.stub(:run).with("heroku config -s --app heroku-commander", { :logger => nil }).
        and_yield("APP_NAME=heroku-commander").
        and_yield("RACK_ENV=staging")
    end
    subject { Heroku::Commander.new({ :app => "heroku-commander" }).config }
    context "config" do
      its(:size) { should == 2 }
      it { subject["APP_NAME"].should eq "heroku-commander" }
    end
  end
  context "with logger" do
    subject do
      logger = Logger.new($stdout)
      Heroku::Commander.new({ :logger => logger })
    end
    context "reload!" do
      it "passes the logger" do
        PTY.stub(:spawn)
        subject.logger.should_receive(:debug).with("Running: heroku config -s")
        subject.config
      end
    end
  end
  context "run" do
    it "runs the command" do
      Heroku::Executor.stub(:run).
        and_yield("Running `...` attached to terminal... up, run.1234").
        and_yield("app").
        and_yield("bin").
        and_yield("rc=0").
        and_return([ "Running `...` attached to terminal... up, run.1234", "app", "bin", "rc=0" ])
      subject.run("ls -1").should == [ "app", "bin" ]
    end
    it "runs the command detached" do
      Heroku::Executor.stub(:run).with("heroku run:detached \"(ls -1 2>&1 ; echo rc=\\$?)\"", { :logger => nil }).
        and_yield("Running `ls -1` detached... up, run.8748").
        and_yield("Use `heroku logs -p run.8748` to view the output.").
        and_yield("rc=0").
        and_return([ "Running `ls -1` detached... up, run.8748", "Use `heroku logs -p run.8748` to view the output.", "rc=0" ])
      Heroku::Executor.stub(:run).with("heroku logs -p run.8748 --tail", { :logger => nil }).
        and_yield("2013-01-31T01:39:30+00:00 heroku[run.8748]: Starting process with command `ls -1`").
        and_yield("2013-01-31T01:39:31+00:00 app[run.8748]: bin").
        and_yield("2013-01-31T01:39:31+00:00 app[run.8748]: app").
        and_yield("2013-01-31T00:56:13+00:00 app[run.8748]: rc=0").
        and_yield("2013-01-31T01:39:33+00:00 heroku[run.8748]: Process exited with status 0").
        and_yield("2013-01-31T01:39:33+00:00 heroku[run.8748]: State changed from up to complete").
        and_return([
          "2013-01-31T01:39:30+00:00 heroku[run.8748]: Starting process with command `ls -1`",
          "2013-01-31T01:39:31+00:00 app[run.8748]: bin",
          "2013-01-31T01:39:31+00:00 app[run.8748]: app",
          "2013-01-31T00:56:13+00:00 app[run.8748]: rc=0",
          "2013-01-31T01:39:33+00:00 heroku[run.8748]: Process exited with status 0",
          "2013-01-31T01:39:33+00:00 heroku[run.8748]: State changed from up to complete"
        ])
      Heroku::Runner.any_instance.should_receive(:terminate_executor!).twice
      subject.run("ls -1", { :detached => true }).should == [ "bin", "app" ]
    end
  end
end

