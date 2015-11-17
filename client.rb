require 'workflow'
require 'highline/import'
require 'rest-client'
require 'reverse_markdown'
require 'colorize'

class MoviePilotClient
  include Workflow

  @id    = nil
  @type  = nil
  @items = []

  workflow do

    state :new do
      event :tag,    :transitions_to => :tag
      event :search, :transitions_to => :search
      event :quit,   :transitions_to => :quit
    end

    state :tag do
      event :read,      :transitions_to => :read
      event :list,      :transitions_to => :list
      event :not_found, :transitions_to => :new
    end

    state :search do
      event :read,      :transitions_to => :read
      event :list,      :transitions_to => :list
      event :not_found, :transitions_to => :new
    end

    state :list do
      event :read,      :transitions_to => :read
    end

    state :read do
      event :new, :transitions_to => :new
    end

    state :quit do

    end

  end

  def start_menu
    @id    = nil
    @type  = nil
    @items = []
    slowput "Pshhh... Pshhh...\nCONNECTED AT 2400/NONE".colorize(:red)
    drawbox("Welcome to MoviePilot BBS!", :yellow)
    slowput "Where are you want to go to?".colorize(:green)
    choose do |menu|
      menu.prompt = "Please enter the number:"
      menu.choice(:tag) {
        say("Let's go to tags menu")
        self.tag!
      }
      menu.choice(:search) {
        say("Let's go to search")
        self.search!
      }
      menu.choice(:quit) {
        self.quit!
      }
    end
  end

  def logout
    exit
  end

  def tag_menu
    puts "What tag are you interested in?  "
    tag = choose do |menu|
      menu.prompt = "Please enter the number:"
      %w(superheroes horror young-adult tv).each{|i|
        menu.choice(i.to_sym)
      }
    end
    puts "Looking for tag #{tag}"
    response = JSON.parse( RestClient.get "http://api.moviepilot.com/v4/tags/#{tag}/trending" )
    if response['collection'].count > 0
      @items = response['collection']
      self.list!
    else
      self.not_found!
    end
  end

  def search_menu
    term = ask("What do you want to find?  ") { |q| q.default = "terminator" }
    response = JSON.parse( RestClient.get "http://api.moviepilot.com/v3/search?q=#{term}&per_page=10&without_type=user,tag" )
    if response['search'].count > 0
      @items = response['search']
      self.list!
    else
      self.not_found!
    end
  end

  def list_items
    puts "What do you want to read?"
    @items.each{|item|
      puts "#{item['id']} (#{item['type']}): #{item['name'] || item['title']}"
    }
    @id = ask("Enter the ID of item:  ") { |q| q.default = @items.first['id'].to_s }
    @type = @items.select{|item| item['id'].to_i == @id.to_i}.first['type']
    self.read!
  end

  def read_item
    puts "Read #{@type} #{@id}"
    response = JSON.parse( RestClient.get "http://api.moviepilot.com/v4/#{@type}s/#{@id}" )
    puts ReverseMarkdown.convert response['html_body']
    self.new!
  end

  private

  def slowput(s = '', line_break = true)
    s.to_s.each_char {|c| putc c ; sleep 0.05; $stdout.flush }
    putc "\n" if line_break
  end

  def drawbox(s = '', color = :white)
    l = s.to_s.length + 6
    b = ''
    l.times do b += '-' end
    b += "\n"
    slowput(b.colorize(color), false);
    slowput("|  #{s}  |".colorize(color))
    slowput(b.colorize(color), false);
  end

end

client = MoviePilotClient.new

loop do
  case client.current_state.name
    when :new
      client.start_menu
    when :quit
      client.logout
    when :tag
      client.tag_menu
    when :search
      client.search_menu
    when :list
      client.list_items
    when :read
      client.read_item
    else
  end
end
