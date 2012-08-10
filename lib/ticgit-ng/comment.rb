module TicGitNG
  class Comment
    attr_accessor :base, :user, :added, :comment

    def initialize( c, user, time=nil )
      raise unless c
      @comment= c
      @user=user
      @added= time.nil? ? Time.now : time
      self
    end

    def self.read( base, file_name, sha )
      type, date, user = file_name.split('_')

      new( (base.git.gblob(sha).contents rescue nil), user, Time.at(date.to_i) )
    end
  end
end
