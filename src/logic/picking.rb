require_relative '../model/team'
require_relative '../model/match'
require_relative '../model/player'
require_relative '../model/stat'
require_relative '../model/user'

module PickingLogic
  def choose_captains
    possible_captains = get_classes["captain"]

    const["teams"]["count"].times do |i|
      captain = possible_captains.delete_at rand(possible_captains.length)
      
      team = Team.new
      team.set_captain captain
      team.set_details const["teams"]["details"][i]
      
      @teams << team
      @signups.delete captain

      notice captain, "You have been selected as a captain. When it is your turn to pick, you can choose players with the '!pick num' or '!pick name' command."
      notice captain, "Remember, you will play the class that you do not pick, so be sure to pick a medic if you do not wish to play medic."
    end
    
    output = @teams.collect { |team| team.my_colourize team.captain }
    message "Captains are #{ output.join(", ") }"
  end
  
  def update_lookup
    @lookup.clear
    @signups.keys.each_with_index { |nick, i| @lookup[i + 1] = nick }
  end

  def tell_captain
    notice current_captain, "It is your turn to pick."

    classes = get_classes
    lookup_i = @lookup.invert
    
    # Displays the classes that are not yet full for this team
    classes_needed(current_team.get_classes).each do |k, v| # logic/players.rb
      output = classes[k].collect { |player| "(#{ lookup_i[player] }) #{ player }" }
      notice current_captain, "#{ bold rjust("#{ v } #{ k }:") } #{ output.join(", ") }"
    end
  end
  
  def list_captain user
    return notice(user, "Picking has not started.") unless state? "picking" # logic/state.rb
 
    message "It is #{ current_captain }'s turn to pick"
  end
  
  def pick_random user, player_class
    classes = get_classes[player_class]
    player = classes[rand(classes.length)]
    
    pick_player user, player, player_class
  end

  def can_pick? nick
    current_captain == nick
  end
  
  def find_player player
    temp = @signups.keys.reject { |k| k.downcase != player.downcase }
    temp.first unless temp.empty?
  end
  
  def pick_class_valid? clss
    const["teams"]["classes"].key? clss
  end
  
  def pick_class_avaliable? player_class
    classes_needed(current_team.get_classes).key? player_class # logic/players.rb
  end

  def pick_player user, player_nick, player_class
    return notice(user, "Picking has not started.") unless state? "picking" # logic/state.rb
    return notice(user, "It is not your turn to pick.") unless can_pick? user.nick

    player_class.downcase!
    player = find_player player_nick
    
    unless player
      player = @lookup[player_nick.to_i] if player_nick.to_i > 0
      return notice(user, "Could not find #{ player_nick }.") unless player
      return notice(user, "#{ player } has already been picked.") unless @signups.key? player
    end
    
    return notice(user, "Invalid class #{ player_class }.") unless pick_class_valid? player_class
    return notice(user, "The class #{ player_class } is full.") unless pick_class_avaliable? player_class

    current_team.signups[player] = player_class
    @signups.delete player
    
    message "#{ current_team.my_colourize user.nick } picked #{ player } as #{ player_class }"
    
    next_pick
  end
  
  def next_pick
    @pick += 1
  
    if @pick >= const["teams"]["total"] - const["teams"]["count"]
      final_pick
    else 
      tell_captain
    end
  end
  
  def final_pick
    end_picking # logic/state.rb
    update_captains
    print_teams

    start_server # logic/server.rb
    announce_server # logic/server.rb
    announce_teams
    
    create_match # takes a while
    end_game # logic/state.rb
    list_players # logic/players.rb
  end
  
  def update_captains
    @teams.each do |team|
      team.signups[team.captain] = classes_needed(team.get_classes).keys.first
    end
  end
 
  def create_match
    match = Match.create :time => Time.now
    
    @teams.each do |team|
      team.save # teams have not been saved up to this point just in case of !endgame
      match.teams << team
      
      # Create each player's statistics
      team.signups.each do |nick, clss|
        u = @auth[nick]
        team.users << u
      
        p = create_player_record u, match, team
        create_stat_record p, "captain" if nick == team.captain # captain gets counted twice
        create_stat_record p, clss
      end
    end
  end
  
  def create_player_record user, match, team
    user.players.create(:match => match, :team => team)
  end
  
  def create_stat_record player, clss
    player.stats.create(:tfclass => Tfclass.find_by_name(clss))
  end
  
  def print_teams
    @teams.each do |team|
      message team.format_team
    end
  end
  
  def announce_teams
    @teams.each do |team|
      team.signups.each do |nick, clss|
        private nick, "You have been picked for #{ team.format_name } as #{ clss }. The server info is: #{ @server.connect_info }" 
      end
    end
  end
  
  def list_format
    output = []
    (const["teams"]["total"] - const["teams"]["count"]).times do |i|
      output << (colourize "#{ i }", const["teams"]["details"][pick_format(i)]["colour"])
    end
    message "The picking format is: #{ output.join(" ") }"
  end
  
  def current_captain
    current_team.captain
  end
  
  def current_team
    @teams[pick_format @pick]
  end
  
  def pick_format num
    staggered num
  end
  
  def sequential num
    # 0 1 0 1 0 1 0 1 ...
    num % const["teams"]["count"]
  end
  
  def staggered num
    # 0 1 1 0 0 1 1 0 ...
    # won't work as expected when const["teams"]["count"] > 2
    ((num + 1) / const["teams"]["count"]) % const["teams"]["count"]
  end
  
  def hybrid num
    # 0 1 0 1
    #         1 0 0 1 1 0 ...
    return sequential(num) if num < 4
    staggered(num - 2)
  end
end
