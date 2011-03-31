require 'tf2pug/database'

require 'tf2pug/model/match'
require 'tf2pug/model/matchup'
require 'tf2pug/model/roster'
require 'tf2pug/model/user'

class Team
  include DataMapper::Resource
  
  property :id,   Serial
  property :name, String, :index => true, :required => true
  
  property :created_at, DateTime
  property :updated_at, DateTime

  has n, :matchups
  has n, :matches,  :through => :matchups
  has n, :rosters,  :constraint => :destroy
  has n, :users,    :through => :rosters
end