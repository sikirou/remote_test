class TicGitNG
    class Attachment
        #origin is only populated when adding a new attachment.
        #It is the path of the original file of the attachment.
        attr_accessor :origin
        #Called when attaching a new attachment and when reading/opening attachments
        def initialize( base, fname, sha )
        end
    end
end
