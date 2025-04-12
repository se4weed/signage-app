require 'aws-sdk-dynamodb'

class Schedule
  Session = Data.define(
    :slug,
    :starts_at,
    :ends_at,
    :track,
    :hall,
    :title,
    :description,
    :speakers,
    :updated_at,
  )
  Speaker = Data.define(
    :slug,
    :name,
    :bio,
    :github_id,
    :twitter_id,
    :avatar_url,
  )
  def initialize(table_name: ENV.fetch('DYNAMODB_TABLE_NAME'), tenant: ENV.fetch('TENANT', 'default'), cache_duration: 60, fix: ENV['SCHEDULE_FIX'])
    @dynamodb = Aws::DynamoDB::Client.new
    @table_name = table_name
    @tenant = tenant
    @cache_duration = cache_duration
    @fix = fix

    @known_speaker_names = nil
    @sessions = nil
    @retrieved_at = nil
  end

  attr_reader :table_name

  def inspect
    "#<#{self.class.name} table_name=#{@table_name} tenant=#{@tenant} fix=#{@fix}>"
  end

  NAME_TENANTS = %w(2023 2024 default)
  def known_speaker_names
    @known_speaker_names ||= NAME_TENANTS.flat_map do |tenant|
      @dynamodb.query(table_name:, expression_attribute_values: {":pk" => "#{tenant}::sessions"}, key_condition_expression: 'pk = :pk').flat_map(&:items).flat_map do |item|
        item.fetch('speakers', []).map do |speaker_info|
          speaker_info.fetch('name').strip
        end
      end
    end.sort.uniq
  end

  def sessions(refresh: false)
    if @sessions.nil? || refresh || (@retrieved_at && (Time.now - @retrieved_at) > @cache_duration)
      @sessions = begin
        pk = "#{@tenant}::sessions"
        @retrieved_at = Time.now
        @dynamodb.query(table_name:, expression_attribute_values: {":pk" => pk}, key_condition_expression: 'pk = :pk').flat_map(&:items).map do |item|
          Session.new(
            slug: item.fetch('slug'),
            starts_at: Time.at(item.fetch('starts_at')).utc,
            ends_at: Time.at(item.fetch('ends_at')).utc,
            track: item.fetch('track'),
            hall: item.fetch('hall'),
            title: item.fetch('title'),
            description: item.fetch('description', ''),
            updated_at: Time.at(item.fetch('updated_at')).utc,
            speakers: item.fetch('speakers', []).map do |speaker_info|
              Speaker.new(
                slug: speaker_info.fetch('slug'),
                name: speaker_info.fetch('name'),
                bio: speaker_info.fetch('bio'),
                github_id: speaker_info.fetch('github_id', nil),
                twitter_id: speaker_info.fetch('twitter_id', nil),
                avatar_url: speaker_info.fetch('avatar_url', nil),
              )
            end,
          )
        end
      end
    end
    @sessions
  end

  def current(track:, now: Time.now.utc)
    return sessions.find { _1.slug == @fix } if @fix
    sessions.select { _1.track == track }.find do |session|
      session.starts_at <= now && now <= session.ends_at
    end
  end
end
