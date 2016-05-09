require 'json'

module Slacky
  class User
    attr_accessor :username, :slack_id, :slack_im_id, :first_name, :last_name, :email, :timezone, :presence, :data
    attr_reader :tz

    @@decorator = @@db = nil

    def self.decorator=(decorator)
      @@decorator = decorator
    end

    def self.db=(db)
      @@db = db
    end

    def self.initialize_table
      @@db.exec <<-SQL
create table if not exists users (
  username     varchar(64) not null,
  slack_id     varchar(20) not null,
  slack_im_id  varchar(20),
  first_name   varchar(64),
  last_name    varchar(64),
  email        varchar(128) not null,
  timezone     varchar(256),
  presence     varchar(64),
  data         jsonb not null
);
SQL
    end

    def self.find(user)
      return user.map { |u| User.find u }.compact if user.is_a? Array
      result = @@db.exec_params "select * from users where slack_id = $1", [ user ]
      if result.ntuples == 0
        result = @@db.exec_params "select * from users where username = $1", [ user ]
      end
      return nil if result.ntuples == 0

      row = result[0]
      user = self.new username:    row['username'],
                      slack_id:    row['slack_id'],
                      slack_im_id: row['slack_im_id'],
                      first_name:  row['first_name'],
                      last_name:   row['last_name'],
                      email:       row['email'],
                      timezone:    row['timezone'],
                      presence:    row['presence'],
                      data:        JSON.parse(row['data'])
      user.extend @@decorator if @@decorator
      user
    end

    def initialize(attrs={})
      @username    = attrs[:username]
      @slack_id    = attrs[:slack_id]
      @slack_im_id = attrs[:slack_im_id]
      @first_name  = attrs[:first_name]
      @last_name   = attrs[:last_name]
      @email       = attrs[:email]
      @timezone    = attrs[:timezone] || "America/Los_Angeles"
      @presence    = attrs[:presence]
      @data        = attrs[:data] || {}
    end

    def populate(member)
      @username   = member.name
      @first_name = member.profile.first_name
      @last_name  = member.profile.last_name
      @email      = member.profile.email
      @timezone   = member.tz
      @presence   = member.presence
      @data       = {} unless @data
      self
    end

    def save
      @@db.exec_params "delete from users where slack_id = $1", [ @slack_id ]
      @@db.exec_params "insert into users (username, slack_id, slack_im_id, first_name, last_name, email, timezone, presence, data)
                        values ($1, $2, $3, $4, $5, $6, $7, $8, $9)",
                        [ @username, @slack_id, @slack_im_id, @first_name, @last_name, @email, @timezone, @presence, JSON.dump(@data) ]
      self
    end

    def reset
      @data = {}
    end
  end
end
