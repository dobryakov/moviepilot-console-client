require 'workflow'
require 'highline/import'
require 'rest-client'

class MoviePilotClient
  include Workflow

  workflow do

    state :new do
      event :tags,   :transitions_to => :tags
      event :search, :transitions_to => :search
    end

    state :tags do
    end

    state :search do
      event :not_found, :transitions_to => :new
    end

    state :read do

    end

  end
end

client = MoviePilotClient.new

loop do

  case client.current_state.name
    when :new

      choose do |menu|
        menu.prompt = "Where are you want to go to?"
        menu.choice(:tags) {
          say("Let's go to tags menu")
          client.tags!
        }
        menu.choice(:search) {
          say("Let's go to search")
          client.search!
        }
      end

    when :search

      term = ask("What do you want to find?  ") { |q| q.default = "none" }

      response = JSON.parse( RestClient.get "http://api.moviepilot.com/v3/search?q=#{term}&per_page=2&without_type=user,tag" )

      if response['search'].count > 0
        puts "What do you want to read?"
        response['search'].each{|item|
          puts "#{item['id']} (#{item['type']}): #{item['name']}"
        }
      else
        client.not_found!
      end

    else
      # nothing
  end

end
