server 'sdr-services-app-prod.stanford.edu', user: 'sdr2service', roles: %w{app}

Capistrano::OneTimeKey.generate_one_time_key!

set :honeybadger_env, 'prod'
