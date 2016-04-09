require 'tzinfo'

class Slacky::User
  attr_accessor :slack_id, :slack_im_id, :timezone, :data

  def self.db=(db)
    @@db = db
  end

  def self.initialize_table
    @@db.exec <<-SQL
create table if not exists users (
  username     varchar(64),
  slack_id     varchar(20),
  slack_im_id  varchar(20),
  timezone     varchar(256),
  presence     varchar(64),
  data         jsonb
);
SQL
  end

  def self.find(slack_id)
    result = @@db.exec_params "select username, slack_im_id, timezone, presence, data from users where slack_id = $1", [ slack_id ]
    return nil if result.ntuples == 0
    row = result[0]
    self.new slack_id:    slack_id,
             username:    row['username'],
             slack_im_id: row['slack_im_id'],
             timezone:    row['timezone'],
             presence:    row['presence'],
             data:        row['data']
  end

  def initialize(attrs={})
    @username    = attrs[:username]
    @slack_id    = attrs[:slack_id]
    @slack_im_id = attrs[:slack_im_id]
    @timezone    = attrs[:timezone] || "America/Los_Angeles"
    @presence    = attrs[:presence]
    @data        = attrs[:data]

    @tz = TZInfo::Timezone.get @timezone
  end

  def save
    @@db.exec_params "delete from users where slack_id = $1", [ @slack_id ]
    @@db.exec_params "insert into users (username, slack_id, slack_im_id, timezone, presence, data)
                      values ($1, $2, $3, $4, $5, $6)", [ @username, @slack_id, @slack_im_id, @timezone, @presence, @data ]
  end

  def reset
    @data = {}
  end

  def has_been_asked_on?(time)
    return false unless @last_ask

    la_time = @tz_la.utc_to_local time.getgm
    la_last_ask = @tz_la.utc_to_local Time.at(@last_ask)
    la_time.strftime('%F') == la_last_ask.strftime('%F')
  end

  def should_ask_at?(time)
    is_work_hours?(time) && ! has_been_asked_on?(time)
  end

  def is_work_hours?(time)
    la_time = @tz_la.utc_to_local time.getgm
    return false if la_time.wday == 0 || la_time.wday == 6  # weekends
    la_time.hour >= 8 && la_time.hour <= 17
  end

  def parking_spot_status
    return 'unknown' unless @last_answer
    @last_answer.downcase == 'yes' ? 'in use' : 'available'
  end
end
