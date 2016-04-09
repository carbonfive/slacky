require 'tzinfo'

class Parky::User
  attr_accessor :slack_user_id, :slack_im_id, :timezone, :data

  def self.db=(db)
    @@db = db
  end

  def self.find(user_id)
    user = nil
    @@db.exec_params "select slack_im_id, from users where slack_user_id = $1", [ user_id ] do |row|
      user = self.new user_id: slack_user_id, slack_im_id: row[0], timezone: row[1], data: row[2]
    end
    user
  end

  def initialize(attrs={})
    @slack_user_id = attrs[:user_id]
    @slack_im_id   = attrs[:im_id]
    @timezone      = attrs[:timezone] || "America/Los_Angeles"
    @data          = attrs[:data]

    @tz = TZInfo::Timezone.get @timezone
  end

  def save
    @@db.exec_params "delete from users where slack_user_id = $1", [ @slack_user_id ]
    @@db.exec_params "insert into users (slack_user_id, slack_im_id, timezone, data)
                      values ($1, $2, $3, $4)", [ @slack_user_id, @slack_im_id, @timezone, @data ]
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
