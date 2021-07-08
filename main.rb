require "sinatra"
require "sinatra/reloader"
require "active_record"
require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "date"
require "fileutils"
use Rack::MethodOverride
set :environment, :production
ActiveRecord::Base.configurations = YAML. load_file ('database.yml')
ActiveRecord::Base.establish_connection :development


OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze
APPLICATION_NAME = "Google Calendar API Ruby Quickstart".freeze
CREDENTIALS_PATH = "credentials.json".freeze
# The file token.yaml stores the user's access and refresh tokens, and is
# created automatically when the authorization flow completes for the first
# time.
TOKEN_PATH = "token.yaml".freeze
SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  client_id = Google::Auth::ClientId.from_file CREDENTIALS_PATH
  token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH
  authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store
  user_id = "default"
  credentials = authorizer.get_credentials user_id
  if credentials.nil?
    url = authorizer.get_authorization_url base_url: OOB_URI
    puts "Open the following URL in the browser and enter the " \
         "resulting code after authorization:\n" + url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI
    )
  end
  credentials
end

# Initialize the API
service = Google::Apis::CalendarV3::CalendarService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

# Fetch the next 10 events for the user
calendar_id = "nnct-info@nagano-nct.ac.jp"
response = service.list_events(calendar_id,
                               max_results:   10,
                               single_events: true,
                               order_by:      "startTime",
                               time_min:      DateTime.now.rfc3339)
puts "Upcoming events:"
puts "No upcoming events found" if response.items.empty?
response.items.each do |event|
  start = event.start.date || event.start.date_time
  puts "- #{event.summary} (#{start})"
end

class Events < ActiveRecord::Base
end

def calc(y, m, d)
    return (y + (y/4) - (y/100) + (y/400) + ((13*m + 8) / 5) + d) % 7
end

def calcMonth(m, n)
    tmpM = m
    tmpM += n
    result = tmpM > 12 ? 1 : tmpM < 1 ? 12 : tmpM
    return result
end

def calcYear(y, m, n)
    tmpM = m
    tmpM += n
    result = tmpM > 12 ? y+1 : tmpM < 1 ? y-1 : y
    return result
end

def colorGudge(y, m, d)
    sty = if(m == 7 && d == 30)
        "#f57f17 amber-text darken-4"
    elsif calc(y, m, d) == 0
        "red-text"
    elsif calc(y, m, d) == 6
        "blue-text"
    else
        "black-text"
    end
    return sty
end

def lastDay(m)
    return case m
    when 1, 3, 5, 7, 8, 10, 12
        31
    when 2, 4, 6, 9, 11
        30
    end
end

get "/" do
    t = Time.new
    @year = t.year
    @month = t.month
    @events = Events.where("date BETWEEN \"#{Time.local(@year, @month, 1).strftime("%Y-%m-%d")}\" AND \"#{Time.local(@year, @month, lastDay(@month)).strftime("%Y-%m-%d")}}\"" )
    @googleEvents = service.list_events(calendar_id,
        max_results:   10,
        single_events: true,
        order_by:      "startTime",
        time_min:      Time.local(@year, @month, 1).rfc3339,
        time_max:      (Time.local(@year, @month + 1, 1) - 1).rfc3339)
    erb :calender
end

get "/:year/:month" do
    @year = params[:year].to_i
    @month = params[:month].to_i
    @events = Events.where("date BETWEEN \"#{Time.local(@year, @month, 1).strftime("%Y-%m-%d")}\" AND \"#{Time.local(@year, @month, lastDay(@month)).strftime("%Y-%m-%d")}}\"" )
    @googleEvents = service.list_events(calendar_id,
        max_results:   10,
        single_events: true,
        order_by:      "startTime",
        time_min:      Time.local(@year, @month, 1).rfc3339,
        time_max:      (Time.local(@year, @month + 1, 1) - 1).rfc3339)
    erb :calender
end

get "/:year/:month/:day" do
    @year = params[:year].to_i
    @month = params[:month].to_i
    @day = params[:day].to_i
    @events = Events.where("date = \"#{Time.local(@year, @month, @day).strftime("%Y-%m-%d")}\"" )
    puts Time.local(@year, @month, @day).strftime("%Y-%m-%d")
    erb :event
end

post "/:year/:month/:day/new" do
    @year = params[:year].to_i
    @month = params[:month].to_i
    @day = params[:day].to_i
    e = Events.new
    e.title = params[:title]
    e.description = params[:description]
    e.date = "#{@year}-#{@month}-#{@day}"
    e.id = [*'A'..'Z', *'a'..'z', *0..9].shuffle[0..9].join
    e.save
    redirect "/#{@year}/#{@month}/#{@day}?saved"
end

delete "/:year/:month/:day/:id" do
    e = Events.find(params[:id])
    e.destroy
    @year = params[:year].to_i
    @month = params[:month].to_i
    @day = params[:day].to_i
    redirect "/#{@year}/#{@month}/#{@day}?deleted"
end