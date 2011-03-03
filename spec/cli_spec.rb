require File.dirname(__FILE__) + "/spec_helper"

describe TicGitNG::CLI do
  include TicGitNGSpecHelper

  before(:all) do
    @path = setup_new_git_repo
    @orig_test_opts = test_opts
    @ticgitng = TicGitNG.open(@path, @orig_test_opts)
  end

  after(:all) do
    Dir.glob(File.expand_path("~/.ticgit-ng/-tmp*")).each {|file_name| FileUtils.rm_r(file_name, {:force=>true,:secure=>true}) }
    Dir.glob(File.expand_path("/tmp/ticgit-ng-*")).each {|file_name| FileUtils.rm_r(file_name, {:force=>true,:secure=>true}) }
  end

  it "should list the tickets"

  it "should show a ticket"

  it 'displays --help' do
    expected = format_expected(<<-OUT)
Please specify at least one action to execute.

Usage: ti COMMAND [FLAGS] [ARGS]
 
The available ticgit commands are:
    recent                           List recent activities
    checkout                         Checkout a ticket
    tag                              Modify tags of a ticket
    comment                          Comment on a ticket
    milestone                        List and modify milestones
    assign                           Assings a ticket to someone
    sync                             Sync tickets
    points                           Assign points to a ticket
    state                            Change state of a ticket
    show                             Show a ticket
    new                              Create a new ticket
    attach                           Attach file to ticket
    list                             List tickets
 
Common options:
    -v, --version                    Show the version number
    -h, --help                       Display this help
    OUT

    cli do |line|
      line.should == expected.shift
    end
  end

  it 'displays empty list' do
    fields = %w[TicId Title State Date Assgn Tags]
    output = []
    # It's unclear why it's necessary to append each line like this, but
    # cli('list') would otherwise return nil. The spec helper probably
    # needs some refactoring.
    cli 'list' do |line|
      output << line
    end
    output.shift.should be_empty
    output.shift.should match /#{fields.join '\s+'}/
    output.shift.should match /^-+$/
  end
end