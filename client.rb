require 'workflow'
require 'highline/import'
require 'rest-client'
require 'reverse_markdown'

class MoviePilotClient
  include Workflow

  @id = nil
  @type = nil

  workflow do

    state :new do
      event :search, :transitions_to => :search
    end

    state :search do
      event :read,      :transitions_to => :read
      event :not_found, :transitions_to => :new
    end

    state :read do
      event :new, :transitions_to => :new
    end

  end

  def start_menu
    #p self.current_state.name
    puts "Where are you want to go to?"
    choose do |menu|
      menu.prompt = "Please input the number:"
      menu.choice(:tags) {
        say("Let's go to tags menu")
        self.tags!
      }
      menu.choice(:search) {
        say("Let's go to search")
        self.search!
      }
    end
  end

  def search_menu
    #p self.current_state.name
    term = ask("What do you want to find?  ") { |q| q.default = "terminator" }
    response = JSON.parse( RestClient.get "http://api.moviepilot.com/v3/search?q=#{term}&per_page=2&without_type=user,tag" )
    if response['search'].count > 0
      puts "What do you want to read?"
      response['search'].each{|item|
        puts "#{item['id']} (#{item['type']}): #{item['name']}"
      }
      @id = ask("Enter the ID of item:  ") { |q| q.default = "3362113" }
      @type = response['search'].select{|item| item['id'].to_i == @id.to_i}.first['type']
      self.read!
    else
      self.not_found!
    end
  end

  def read_item
    puts "Read #{@type} #{@id}"
    response = JSON.parse( RestClient.get "http://api.moviepilot.com/v4/#{@type}s/#{@id}" )
    puts ReverseMarkdown.convert response['html_body']
    self.new!
  end

end

client = MoviePilotClient.new

loop do
  case client.current_state.name
    when :new
      client.start_menu
    when :search
      client.search_menu
    when :read
      client.read_item
    else
  end
end
