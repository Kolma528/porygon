require "json"
require "net/http"
require "cgi"

class GoNintendo
  include Cinch::Plugin

  def initialize(*args)
    super
    @last_top_story_url ||= {}
  end

  match /http:\/\/w{0,3}\.?gonintendo\.com\/s\/([a-z\-0-9]+)/i, :use_prefix => false, :strip_colors => true, :method => "get_gonintendo_story"
  match /http:\/\/w{0,3}\.?gonintendo\.com\/\?mode=viewstory&id=([0-9]+)/i, :use_prefix => false, :strip_colors => true, :method => "get_gonintendo_story"
  match /http:\/\/w{0,3}\.?gonintendo\.com\/m\/\?id=([0-9]+)/i, :use_prefix => false, :strip_colors => true, :method => "get_gonintendo_story_mobile"
  timer (10 * 60), :method => :check_sites

  def get_gonintendo_story(m, story_id)
    body = check_gonintendo(story_id.to_i)
    return if body.nil?
    send_reply m, body
  end

  def get_gonintendo_story_mobile(m, story_id)
    body = check_gonintendo(story_id.to_i)
    return if body.nil?
    send_reply m, "#{body} http://gonintendo.com/s/#{story_id}"
  end

  def check_sites
    [
      {:url => "http://www.gonintendo.com/content/json/chrome-1.json", :channel => "#gonintendo"},
    ].each do |site|
      check_site(site)
    end
  end

  private ######################################################################

  def check_gonintendo(story_id)
    body = make_request("http://www.gonintendo.com/feeds/porygon_story_json.php?id=#{story_id}")
    return nil if body.nil?
    rating = body['thumbs_up'].to_i - body['thumbs_down'].to_i
    "#{body["title"]} (Posted on #{body["published"]}) Rating: #{rating} [+#{body["thumbs_up"].to_i} -#{body["thumbs_down"].to_i}]"
  end

  def send_reply(m, reply)
    m.reply reply
  end

  def check_site(site)
    body = make_request(site[:url])
    return if body.nil?

    messages = build_messages(site[:channel], body)
    return if messages.empty?

    send_messages(site[:channel], messages)
  end

  def build_messages(channel, body)
    messages = []

    first_top_story_url = body['top_stories'].first['url']
    if @last_top_story_url[channel].nil?
      @last_top_story_url[channel] = first_top_story_url
      return []
    end

    if @last_top_story_url[channel] != first_top_story_url
      old_top_story_url = @last_top_story_url[channel]
      @last_top_story_url[channel] = first_top_story_url
      body['top_stories'].each do |ts|
        if ts['url'] != old_top_story_url
          messages << "New Top Story: #{ts['title']} - #{ts['url']}"
        else
          break
        end
      end
    end
    messages
  end

  def send_messages(channel, messages)
    messages.each do |message|
      Channel(channel).send message
    end
  end

  def make_request(url)
    url = URI.parse(url)
    req = Net::HTTP::Get.new(url.request_uri)
    res = Net::HTTP.start(url.host, url.port) {|http| http.request(req) }
    return nil unless res.code == "200"
    JSON.parse(res.body)
  rescue
    nil
  end
end
