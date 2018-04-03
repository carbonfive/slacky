require 'json'

module Slacky
  class User
    attr_accessor :username, :slack_id, :slack_im_id, :first_name, :last_name, :email, :timezone, :data
    attr_writer :valid
    attr_reader :tz

    def valid?
      @valid
    end

    @@decorator = @@config = @@db = nil

    def self.decorator=(decorator)
      @@decorator = decorator
    end

    def self.config=(config)
      @@config = config
    end

    def self.db
      return @@db if @@db
      @@db = @@config.db
      initialize_table
      @@db
    end

    def self.initialize_table
      self.db.exec <<-SQL
create table if not exists users (
  username     varchar(64) not null,
  slack_id     varchar(20) not null,
  slack_im_id  varchar(20),
  first_name   varchar(64),
  last_name    varchar(64),
  email        varchar(128) not null,
  timezone     varchar(256),
  valid        boolean not null default false,
  data         jsonb not null
);
SQL
    end

    def self.invalidate_all_users
      self.db.exec 'update users set valid = FALSE'
    end

    def self.find(user)
      return nil unless user
      return user.map { |u| User.find u }.compact if user.is_a? Array
      match = user.match(/^<@(.*)>$/)
      id = ( match ? match[1] : user )
      result = self.db.exec_params "select * from users where slack_id = $1", [ id ]
      if result.ntuples == 0
        username = ( user =~ /^@/ ? user.sub(/^@/, '') : user )
        result = self.db.exec_params "select * from users where username = $1", [ username ]
      end
      return nil if result.ntuples == 0
      hydrate(result)[0]
    end

    def self.find_by_data(query)
      result = self.db.exec "select * from users where data #{query}"
      hydrate result
    end

    def self.hydrate(result)
      return [] if result.ntuples == 0
      result.map do |row|
        user = self.new username:    row['username'],
                        slack_id:    row['slack_id'],
                        slack_im_id: row['slack_im_id'],
                        first_name:  row['first_name'],
                        last_name:   row['last_name'],
                        email:       row['email'],
                        timezone:    row['timezone'],
                        valid:       row['valid'],
                        data:        JSON.parse(row['data'])
        user.extend @@decorator if @@decorator
        user
      end
    end

    def initialize(attrs={})
      @username    = attrs[:username]
      @slack_id    = attrs[:slack_id]
      @slack_im_id = attrs[:slack_im_id]
      @first_name  = attrs[:first_name]
      @last_name   = attrs[:last_name]
      @email       = attrs[:email]
      @timezone    = attrs[:timezone] || "America/Los_Angeles"
      @valid       = attrs[:valid]
      @data        = attrs[:data] || {}
    end

    def populate(member)
      @username   = member.name
      @first_name = member.profile.first_name
      @last_name  = member.profile.last_name
      @email      = member.profile.email
      @timezone   = member.tz
      @data       = {} unless @data
      self
    end

    def validate
      @valid = true
      self
    end

    def save
      User.db.exec_params "delete from users where slack_id = $1", [ @slack_id ]
      User.db.exec_params "insert into users (username, slack_id, slack_im_id, first_name, last_name, email, timezone, valid, data)
                           values ($1, $2, $3, $4, $5, $6, $7, $8, $9)",
                          [ @username, @slack_id, @slack_im_id, @first_name, @last_name, @email, @timezone, @valid, JSON.dump(@data) ]
      self
    end

    def reset
      @data = {}
    end
  end
end
