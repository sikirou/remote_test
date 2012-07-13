module TicGitNG
  class Ticket

    attr_reader :base, :opts
    attr_accessor :ticket_id, :ticket_name
    attr_accessor :title, :state, :milestone, :assigned, :opened, :points
    attr_accessor :comments, :tags, :attachments # arrays

    def initialize(base, options = {})
      # FIXME: what/where/who/how changed config to hash?
      if (cfg = base.git.config).is_a? Hash
        options[:user_name] ||= cfg["user.name"]
        options[:user_email] ||= cfg["user.email"]
      else
        options[:user_name] ||= cfg("user.name")
        options[:user_email] ||= cfg("user.email")
      end

      @base = base
      @opts = options || {}

      @state = 'open' # by default
      @comments = []
      @tags = []
      @attachments = []
    end

    def self.create(base, title, options = {})
      t = Ticket.new(base, options)
      t.title = title
      t.ticket_name = self.create_ticket_name(title)
      t.save_new
      t
    end

    def self.open(base, ticket_name, ticket_hash, options = {})
      tid = nil

      t = Ticket.new(base, options)
      t.ticket_name = ticket_name

      title, date = self.parse_ticket_name(ticket_name)
      t.opened = date

      ticket_hash['files'].each do |fname, sha|
        if fname == 'TICKET_ID'
          tid = sha
        elsif fname == 'TICKET_TITLE'
          t.title = base.git.gblob(sha).contents
        else
          # matching
          data = fname.split('_')

          case data[0]
          when 'ASSIGNED'
            t.assigned = data[1]
          when 'ATTACHMENTS'
            #FIXME attach
              #Attachments dir naming format:
              #ticket_name/ATTACHMENTS/123456_jeff.welling@gmail.com_fubar.jpg
              #data[] format:
              #"ATTACHMENTS_1342116799_jeff.welling@gmail.com_Rakefile".split('_')
              #
              # Find out what fname and sha are for when ATTACHMENTS is a dir
              # and we hit here. Breakout attachments reading to function.
              filename=File.join( 'ATTACHMENTS', fname.gsub(/^ATTACHMENTS_/,'') )
            t.attachments << TicGitNG::Attachment.new(base, filename, sha)
          when 'COMMENT'
            t.comments << TicGitNG::Comment.new(base, fname, sha)
          when 'POINTS'
            t.points = base.git.gblob(sha).contents.to_i
          when 'STATE'
            t.state = data[1]
          when 'TAG'
            t.tags << data[1]
          when 'TITLE'
            t.title = base.git.gblob(sha).contents
          end
        end
      end

      t.ticket_id = tid
      t
    end

    def self.parse_ticket_name(name)
      epoch, title, rand = name.split('_')
      title = title.gsub('-', ' ')
      return [title, Time.at(epoch.to_i)]
    end

    # write this ticket to the git database
    def save_new
      base.in_branch do |wd|
        files=[]
        t=nil
        base.logger.puts "saving #{ticket_name}"

        Dir.mkdir(ticket_name)
        Dir.chdir(ticket_name) do
          base.new_file('TICKET_ID', ticket_name)
          files << File.join( ticket_name, 'TICKET_ID' )
          base.new_file('TICKET_TITLE', title)
          files << File.join( ticket_name, 'TICKET_TITLE' )
          base.new_file( (t='ASSIGNED_'+email) , email)
          files << File.join( ticket_name, t )
          base.new_file( (t='STATE_'+state) , state)
          files << File.join( ticket_name, t )
          base.new_file('TITLE', title)
          files << File.join( ticket_name, 'TITLE' )

          # add initial comment
          #COMMENT_080315060503045__schacon_at_gmail
          if opts[:comment]
            base.new_file(t=comment_name(email), opts[:comment])
            files << File.join( ticket_name, t )
          end

          # add initial tags
          if opts[:tags] && opts[:tags].size > 0
            opts[:tags] = opts[:tags].map { |t| t.strip }.compact
            opts[:tags].each do |tag|
              if tag.size > 0
                tag_filename = 'TAG_' + Ticket.clean_string(tag)
                if !File.exists?(tag_filename)
                  base.new_file(tag_filename, tag_filename)
                  files << File.join( ticket_name, tag_filename )
                end
              end
            end
          end
        end
        files.each {|file|
          base.git.add file
        }
        base.git.commit("added ticket #{ticket_name}")
      end
      # ticket_id
    end

    def self.clean_string(string)
      string.downcase.gsub(/[^a-z0-9]+/i, '-')
    end

    def add_comment(comment)
      return false if !comment
      base.in_branch do |wd|
        t=nil
        Dir.chdir(ticket_name) do
          base.new_file(t=comment_name(email), comment)
        end
        base.git.add File.join(ticket_name, t)
        base.git.commit("added comment to ticket #{ticket_name}")
      end
    end

    def add_attach( attachment )
        raise ArgumenError, "add_attach() argument must be of class TicGitNG::Attachment" unless attachment.class==TicGitNG::Attachment
        base.in_branch do |wd|
            #Attachment naming format:
            #ticket_name/ATTACHMENTS/123456_jeff.welling@gmail.com_fubar.jpg
            attachments_dirname= File.join( ticket_name, 'ATTACHMENTS' )
            a_name= File.expand_path( File.join(
                attachments_dirname, create_attachment_name(attachment.filename)
            ))
            #if first attachment, create dir
            if File.exist?( attachments_dirname ) && !File.directory?( attachments_dirname )
                puts "Could not create ATTACHMENTS directory"
                exit 1
            elsif !File.directory?( attachments_dirname )
                Dir.mkdir attachments_dirname
            end
            Dir.chdir( attachments_dirname ) do
                #To avoid having to copy the file, use a hardlink instead
                #hardlink the file into attachments_dirname
                FileUtils.ln( attachment.filename, a_name )
            end
            base.git.add a_name
            base.git.commit("added attachment #{File.basename(attachment.filename)} to ticket #{ticket_name}")
        end
    end

    #file_id can be one of:
    #  - An index number of the attachment (1,2,3,...)
    #  - A filename (fubar.jpg)
    #  - nil (nil) means use the last attachment
    #
    #if new_filename is nil, use existing filename
    def get_attach file_id=nil, new_filename=nil
        attachment=nil
        prefix=Dir.pwd
        base.in_branch do |wd|
            if file_id.to_i==0 and file_id=="0"
                attachment= attachments[0]
            elsif file_id.to_i  > 0
                attachment= attachments[file_id.to_i]
            else
                #find attachment by filename
                attachments.each {|a|
                    attachment=a if a.filename.split('_').pop==file_id
                }
            end

            if new_filename
                filename= File.join( prefix, new_filename )
            else
                filename= File.join( prefix, File.basename(attachment.filename).split('_').pop )
            end
            #save attachment [as new_filename]
            FileUtils.ln( File.join( ticket_name, attachment.filename ), filename )
        end
    end

    def change_state(new_state)
      return false if !new_state
      return false if new_state == state
      t=nil

      base.in_branch do |wd|
        Dir.chdir(ticket_name) do
          base.new_file(t='STATE_' + new_state, new_state)
        end
        base.git.remove(File.join(ticket_name,'STATE_' + state))
        base.git.add File.join(ticket_name, t)
        base.git.commit("added state (#{new_state}) to ticket #{ticket_name}")
      end
    end

    def change_assigned(new_assigned)
      new_assigned ||= email
      old_assigned= assigned || ''
      return false if new_assigned == old_assigned

      base.in_branch do |wd|
        t=nil
        Dir.chdir(ticket_name) do
          base.new_file(t='ASSIGNED_' + new_assigned, new_assigned)
        end
        base.git.remove(File.join(ticket_name,'ASSIGNED_' + old_assigned))
        base.git.add File.join(ticket_name,t)
        base.git.commit("assigned #{new_assigned} to ticket #{ticket_name}")
      end
    end

    def change_points(new_points)
      return false if new_points == points

      base.in_branch do |wd|
        Dir.chdir(ticket_name) do
          base.new_file('POINTS', new_points)
        end
        base.git.add File.join(ticket_name, 'POINTS')
        base.git.commit("set points to #{new_points} for ticket #{ticket_name}")
      end
    end

    def add_tag(tag)
      return false if !tag
      files=[]
      added = false
      tags = tag.split(',').map { |t| t.strip }
      base.in_branch do |wd|
        Dir.chdir(ticket_name) do
          tags.each do |add_tag|
            if add_tag.size > 0
              tag_filename = 'TAG_' + Ticket.clean_string(add_tag)
              if !File.exists?(tag_filename)
                base.new_file(tag_filename, tag_filename)
                files << File.join( ticket_name, tag_filename )
                added = true
              end
            end
          end
        end
        if added
          files.each {|file|
            base.git.add file
          }
          base.git.commit("added tags (#{tag}) to ticket #{ticket_name}")
        end
      end
    end

    def remove_tag(tag)
      return false if !tag
      removed = false
      tags = tag.split(',').map { |t| t.strip }
      base.in_branch do |wd|
        tags.each do |add_tag|
          tag_filename = File.join(ticket_name, 'TAG_' + Ticket.clean_string(add_tag))
          if File.exists?(tag_filename)
            base.git.remove(tag_filename)
            removed = true
          end
        end
        if removed
          base.git.commit("removed tags (#{tag}) from ticket #{ticket_name}")
        end
      end
    end

    def path
      File.join(state, ticket_name)
    end

    def comment_name(email)
      'COMMENT_' + Time.now.to_i.to_s + '_' + email
    end

    def email
      opts[:user_email] || 'anon'
    end

    def assigned_name
      assigned.split('@').first rescue ''
    end

    def self.create_ticket_name(title)
      [Time.now.to_i.to_s, Ticket.clean_string(title), rand(999).to_i.to_s].join('_')
    end
    
    def create_attachment_name( attachment_name )
        raise ArgumentError, "create_attachment_name( ) only takes a string" unless attachment_name.class==String
        Time.now.to_i.to_s+'_'+email+'_'+File.basename( attachment_name )
    end
  end
end
