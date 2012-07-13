module TicGitNG
    class Attachment
        attr_reader :user, :added, :filename, :sha, :attachment_name
        #Called when attaching a new attachment and when reading/opening attachments
        def initialize( base, fname, sha=nil )
            @base=base
            @filename=fname
            #sha may be nil if the ticket is being attached
            @sha=sha
            @added, @user, @attachment_name = File.basename(fname).split('_')
            @added= Time.at(@added.to_i)
        end
    end
end
