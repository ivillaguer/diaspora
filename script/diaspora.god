God.pid_file_directory = '/home/lprelle/diaspora/pids'

God::Contacts::Email.defaults do |d|
  d.from_email = 'mail@despora.de'
  d.to_email = 'mail@despora.de'
  d.from_name = 'God'
  d.delivery_method = :sendmail
end
God.contact(:email) do |c|
  c.name = 'lennart'
  c.group = 'developers'
end
rails_env   = ENV['RAILS_ENV']  || "production"
rails_root  = ENV['RAILS_ROOT'] || "/home/lprelle/diaspora"
num_sidekiqworkers = 2


num_sidekiqworkers.times do |num|
  God.watch do |w|
    w.dir      = "#{rails_root}"
    w.name     = "sidekiq-#{num}"
    w.group    = 'diaspora'
    w.interval = 300.seconds
    w.env      = {"QUEUE"=>"photos,receive_local,receive_salmon,receive,mail,socket_webfinger,delete_account,dispatch,http,http_service", "RAILS_ENV"=>rails_env}
    w.start    = "bundle exec sidekiq"
    w.log      = "#{rails_root}/log/sidekiq.log"

    # restart if memory gets too high
    w.transition(:up, :restart) do |on|
      on.condition(:memory_usage) do |c|
        c.above = 2000.megabytes
        c.times = 2
        c.notify = 'lennart'
      end
    end

    # determine the state on startup
    w.transition(:init, { true => :up, false => :start }) do |on|
      on.condition(:process_running) do |c|
        c.running = true
      end
    end

    # determine when process has finished starting
    w.transition([:start, :restart], :up) do |on|
      on.condition(:process_running) do |c|
        c.running = true
        c.interval = 15.seconds
      end

      # failsafe
      on.condition(:tries) do |c|
        c.times = 5
        c.transition = :start
        c.interval = 15.seconds
      end
    end

    # start if process is not running
    w.transition(:up, :start) do |on|
      on.condition(:process_running) do |c|
        c.running = false
        c.notify = 'lennart'
      end
    end
  end
end

God.watch do |w|
  #pid_file = "#{rails_root}/pids/unicorn.pid"

  w.name = "unicorn"
  w.interval = 60.seconds
  w.group    = 'diaspora'
  w.dir = "#{rails_root}"

  # unicorn needs to be run from the rails root
  w.start = "unicorn -c #{rails_root}/config/unicorn.rb -E production -p 3000 -D"

  # QUIT gracefully shuts down workers
  #w.stop = "kill -QUIT `cat #{pid_file}`"

  # USR2 causes the master to re-create itself and spawn a new worker pool
  #w.restart = "kill -USR2 `cat #{pid_file}`"

  #w.start_grace = 10.seconds
  #w.restart_grace = 10.seconds
  #w.pid_file = pid_file

  w.behavior(:clean_pid_file)

  w.start_if do |start|
    start.condition(:process_running) do |c|
      c.interval = 5.seconds
      c.running = false
    end
  end

  w.restart_if do |restart|
    restart.condition(:memory_usage) do |c|
      c.above = 600.megabytes
      c.times = [3, 5] # 3 out of 5 intervals
      c.notify = 'lennart'
    end

    restart.condition(:cpu_usage) do |c|
      c.above = 80.percent
      c.times = 5
      c.notify = 'lennart'
    end
  end

  # lifecycle
  w.lifecycle do |on|
    on.condition(:flapping) do |c|
      c.to_state = [:start, :restart]
      c.times = 5
      c.within = 5.minute
      c.transition = :unmonitored
      c.retry_in = 10.minutes
      c.retry_times = 5
      c.retry_within = 2.hours
    end
  end
end
