
require File.dirname(__FILE__) + "/spec_helper"

describe TicGitNG::Attachment do
  include TicGitNGSpecHelper

  before(:all) do
    @path = setup_new_git_repo
    @orig_test_opts = test_opts
    @ticgitng = TicGitNG.open(@path, @orig_test_opts)
  end

  after(:all) do
    Dir.glob(File.expand_path("~/.ticgit-ng/-tmp*")).each {|file_name| FileUtils.rm_r(file_name, {:force=>true,:secure=>true}) }
    Dir.glob(File.expand_path("~/.ticgit/-tmp*")).each {|file_name| FileUtils.rm_r(file_name, {:force=>true,:secure=>true}) }
    Dir.glob(File.expand_path("/tmp/ticgit-ng-*")).each {|file_name| FileUtils.rm_r(file_name, {:force=>true,:secure=>true}) }
  end

  it "should be able to add an attachment to a ticket" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        #create a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        new_file( attachment_fname=File.join( to_attach, 'fubar.txt' ), "I am the contents of the attachment" )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname, tic.ticket_id ) 
        #check that the file was attached
        tic.attachments.map {|a|
            a.filename.split('_').pop=='fubar.txt'
        }.index( true ).should_not == nil
    end
  end
  it "should support multiple attachments per ticket" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        #create a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        new_file( attachment_fname1=File.join( to_attach, 'fubar.txt' ), "I am the contents of the attachment" )
        new_file( attachment_fname2=File.join( to_attach, 'fubar.jpg' ), "More contents!" )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname1, tic.ticket_id ) 
        tic= @ticgitng.ticket_attach( attachment_fname2, tic.ticket_id )
        tic= @ticgitng.ticket_show( tic.ticket_id )
        #check that the file was attached
        cond_1=false
        cond_2=false
        tic.attachments.map {|a|
            if a.filename.split('_').pop=='fubar.txt'
                cond_1=true
            elsif a.filename.split('_').pop=='fubar.jpg'
                cond_2=true
            end
        }
        [cond_1,cond_2].uniq.size.should == 1
        cond_1.should == true
    end
  end
  it "should be able to see an attachment that has been added to a ticket" do
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        #create a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        contents="I am the contents of the attachment"
        new_file( attachment_fname=File.join( to_attach, 'fubar.txt' ), contents )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname, tic.ticket_id ) 
        #check that the file was attached with details
        tic.attachments.size.should == 1
        tic.attachments[0].attachment_name.should == 'fubar.txt'
        tic.email.should == tic.attachments[0].user
        read_line_of(tic.attachments[0].filename).strip.should == contents 
    end
  end
  it "should be able to get the attachment based on 'AttachmentID'" do     #AttachmentID is a number
    Dir.chdir(File.expand_path( tmp_dir=Dir.mktmpdir('ticgit-ng-gitdir1-') )) do
        tic= @ticgitng.ticket_new('my_delicious_ticket')
        #create a file to attach
        to_attach= Dir.mktmpdir('to_attach')
        new_file( attachment_fname1=File.join( to_attach, 'fubar.txt' ), "I am the contents of the attachment" )
        new_file( attachment_fname2=File.join( to_attach, 'fubar.jpg' ), "More contents!" )
        #attach the file
        tic= @ticgitng.ticket_attach( attachment_fname1, tic.ticket_id ) 
        tic= @ticgitng.ticket_attach( attachment_fname2, tic.ticket_id )
        tic= @ticgitng.ticket_show( tic.ticket_id )
        #check that the file was attached
        cond_1=false
        cond_2=false
        tic.attachments.map {|a|
            if a.filename.split('_').pop=='fubar.txt'
                cond_1=true
            elsif a.filename.split('_').pop=='fubar.jpg'
                cond_2=true
            end
        }
        [cond_1,cond_2].uniq.size.should == 1
        cond_1.should == true
    end
  end
  it "should be able to get the attachment based on filename"
  it "should be able to list the attachments on the current ticket"  #`ti attach list`
  it "should not change the attachment that has been attached if the local file changes"
end
