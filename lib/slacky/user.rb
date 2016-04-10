require 'json'

class Slacky::User
  attr_accessor :username, :slack_id, :slack_im_id, :first_name, :last_name, :email, :timezone, :presence, :data
  attr_reader :tz

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
  data         jsonb not null default '{}'
);
SQL
  end

  def self.find(slack_id_or_name)
    result = @@db.exec_params "select * from users where slack_id = $1", [ slack_id_or_name ]
    if result.ntuples == 0
      result = @@db.exec_params "select * from users where username = $1", [ slack_id_or_name ]
    end
    return nil if result.ntuples == 0

    row = result[0]
    self.new username:    row['username'],
             slack_id:    row['slack_id'],
             slack_im_id: row['slack_im_id'],
             first_name:  row['first_name'],
             last_name:   row['last_name'],
             email:       row['email'],
             timezone:    row['timezone'],
             presence:    row['presence'],
             data:        JSON.parse(row['data'])
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
    @data        = attrs[:data] || '{}'
  end

  def save
    @@db.exec_params "delete from users where slack_id = $1", [ @slack_id ]
    @@db.exec_params "insert into users (username, slack_id, slack_im_id, first_name, last_name, email, timezone, presence, data)
                      values ($1, $2, $3, $4, $5, $6, $7, $8, $9)",
                      [ @username, @slack_id, @slack_im_id, @first_name, @last_name, @email, @timezone, @presence, JSON.dump(@data) ]
  end

  def reset
    @data = {}
  end
end
