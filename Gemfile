
source 'https://rubygems.org'

gem 'json_pure'
gem 'sinatra', '~> 1.4'
gem 'sinatra-contrib'
gem 'sinatra-advanced-routes'

gem 'rack', '~> 1.5'
gem 'thin'
gem 'sys-filesystem'
gem 'pry'
gem 'slop'  # CLI parser

gem 'druid-tools'

# TODO: publish moab-versioning 1.4.0 to rubygems
gem 'moab-versioning', '~> 1.4' #, :path => '/data/src/dlss/moab-versioning' #
#gem 'moab-versioning', :git => 'https://github.com/sul-dlss/moab-versioning.git' #, :branch => 'ruby_ver2_update'

# Databases
gem 'ruby-oci8' # oracle
gem 'sqlite3'
gem 'sequel'

# Templating for /views/documentation
gem 'haml'
gem 'redcarpet'

group :development do
	gem 'awesome_print'
	gem 'equivalent-xml'
  gem 'rack-test', :require => "rack/test"
	gem 'rspec', '< 3.0'
	gem 'simplecov', '~> 0.7.1'
  gem 'yard'
  #gem 'yard-restful'
  #gem 'yard-sinatra'
end

# Do not place the capistrano-related gems in the default or Rails.env bundle group
# Otherwise the config/application.rb's Bundle.require command will try to load them
# leading to failure because these gem's rake task files use capistrano DSL.
group :deployment do
# Use Capistrano for deployment
  gem 'capistrano', '~> 3.1'
  gem 'capistrano-bundler', '~> 1.1'
  gem 'capistrano-rvm', '~> 0.1'
  gem 'lyberteam-capistrano-devel', '~> 3.0'
end
