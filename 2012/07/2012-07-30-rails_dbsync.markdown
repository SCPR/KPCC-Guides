## Rails: Synchronizing your development database with your production database using Rake tasks
###### July 30, 2012

If you run an active website with lots of new content every day, it's often helpful to 
keep your local database up-to-date with your production database, so when you're working 
on the application locally you're working with fresh content.

Here are a couple rake tasks that you can copy-and-paste into your local Rails application 
which will make this syncing process a one-step process.

The tasks assume a few things:

1. You are using mysql locally. If not, change the `merge` task accordingly.
2. You have `rsync` and `scp` installed locally. You probably do.
3. You have some sort of process (probably a cronjob) that periodically dumps the production
   database into a dump file on the remote server. This task will not generate the dump file
   for you.
4. You have some configuration setup in your `development.rb` that looks like this:

```ruby
  config.dbsync             = ActiveSupport::OrderedOptions.new
  config.dbsync.filename    = "yourapp_production.dump"
  config.dbsync.local_dir   = "#{Rails.root}/../dbsync" # No trailing slash
  config.dbsync.remote_host = "db.yourserver.com"
  config.dbsync.remote_dir  = "/web/dbsync/"
```

Then just copy and paste this into `yourapp/lib/tasks/dbsync.rake` and run `rake -T dbsync` 
to see the available tasks!

```ruby
desc "Alias for dbsync:pull"
task :dbsync do
  Rake::Task["dbsync:pull"].invoke
end

namespace :dbsync do
  task :dump_file_config => :environment do
    if Rails.env == 'production'
      raise "These tasks are destructive and shouldn't be used in the production environment."
    end
    
    DUMP  = Rails.application.config.dbsync
    DB    = ActiveRecord::Base.configurations[Rails.env]
    
    DUMP['remote']  = "#{DUMP['remote_host']}:" + File.join(DUMP['remote_dir'], DUMP['filename'])
    DUMP['local']   = File.join DUMP['local_dir'], DUMP['filename']

    if DUMP['filename'].blank?
      raise "No dump filename specified."
    elsif DUMP['remote'].blank?
      raise "No remote dump file specified."
    end
  end
  
  #-----------------------
  
  desc "Show the configuration"
  task :config => :dump_file_config do
    $stderr.puts "Config: "
    $stderr.puts DUMP.to_yaml
  end
    
  #-----------------------
    
  desc "Update the local dump file, and merge it into the local database"
  task :pull => [:fetch, :merge]
  
  desc "Copy the remote dump file, reset the local database, and load in the dump file"
  task :clone => [:clone_dump, :reset, :merge]
  
  #-----------------------
  
  desc "Update the local dump file from the remote source"
  task :fetch => :dump_file_config do
    $stderr.puts "Fetching #{DUMP['remote']} using rsync"
    `rsync -v #{DUMP['remote']} #{DUMP['local']}`
    $stderr.puts "Finished."
  end

  #-----------------------

  desc "Copy the remote dump file to a local destination"
  task :clone_dump => :dump_file_config do
    $stderr.puts "Fetching #{DUMP['remote']} using scp"
    `scp #{DUMP['remote']} #{DUMP['local_dir']}/`
    $stderr.puts "Finished."
  end

  #-----------------------
  
  desc "Merge the local dump file into the local database"
  task :merge => :dump_file_config do
    $stderr.puts "Dumping data from #{DUMP['local']} into #{DB['database']}"
    `mysql \
    #{"-u "+ DB['username'] if DB['username'].present?} \
    #{"-p " + DB['password'] if DB['password'].present?} \
    #{"-h " + DB['host'] if DB['host'].present?} \
    #{DB['database']} < #{DUMP['local']}`
    $stderr.puts "Finished."
  end

  #-----------------------
  
  task :reset do
    $stderr.puts "Resetting Database..."
    Rake::Task["db:reset"].invoke
  end
end
```

###### Tags: rails, database, development, rake
