require 'rspec/core/rake_task'

XVFB_LAUNCH_TIMEOUT = 10

# --env check
def verify_environment
	ensure_xvfb_is_running
	puts "Xvfb is ALIVE!"
end

def ensure_xvfb_is_running
	start_time = Time.now
	begin
		sleep 0.01 # to avoid cpu hogging
		raise "Xvfb is frozen" if (Time.now-start_time)>=XVFB_LAUNCH_TIMEOUT
	end while !xvfb_running?
end

def xvfb_running?
	!!read_xvfb_pid
end

def pid_filename
	"/tmp/.X#{ENV['DISPLAY'].gsub(':','').strip.to_i.to_s}-lock"
end

def read_xvfb_pid
	pid = (File.read(pid_filename) rescue "").strip.to_i
	pid = nil if pid.zero?
	
	if pid
		begin
			Process.kill(0, pid)
			pid
		rescue Errno::ESRCH
			nil
		end
	else
		nil
	end
end

desc 'run tests against the cloud'
RSpec::Core::RakeTask.new(:spec) do |t|
	puts "running spec as a sanity against webrobot"
	ENV['WR_INTERFACE'] = ENV['WR_INTERFACE'].nil? ? "sauce" : ENV['WR_INTERFACE']		
	
	if ! ENV['WR_DEBUG'].nil?
		Rake::Task["env:display"].reenable
		Rake::Task["env:display"].invoke
	end
		
	# opt
	#t.pattern = ENV["FILE"].nil? ? ["./spec/**/*.rb","./spec/*.rb"] : ENV["FILE"]
	t.pattern = ENV["FILE"].nil? ? [File.join(File.dirname(__FILE__), "../../home/tasks/*_webrobot.rb")] : ENV["FILE"]
	t.rspec_opts = ['-f html', '-o results.html', '--color']
	t.verbose = true
end

desc 'run tests against the cloud'
RSpec::Core::RakeTask.new(:sauce) do |t|
	puts "running sauce as a target interface"
	ENV['WR_INTERFACE'] = ENV['WR_INTERFACE'].nil? ? "sauce" : ENV['WR_INTERFACE']		
	
	if ! ENV['WR_DEBUG'].nil?
		Rake::Task["env:display"].reenable
		Rake::Task["env:display"].invoke
	end

	# opt
	t.pattern = ENV["FILE"].nil? ? ["./tests/**/*_test.rb","./tests/*_test.rb"] : ENV["FILE"]
	t.rspec_opts = ['-f html', '-o results.html', '--color']
	t.verbose = true
end

desc 'Setup and teardown features, run tests against the selenium driver'
namespace :local do

	desc "Setup fixtures for HEADED and execute the tests. WR_DISPLAY=:5 will override the DISPLAY used."
	RSpec::Core::RakeTask.new(:headed) do |t|
			ENV['DISPLAY'] = ENV['WR_DISPLAY'] = ENV['WR_DISPLAY'].nil? ? ':5' : ENV['WR_DISPLAY']
			ENV['WR_INTERFACE'] = ENV['WR_INTERFACE'].nil? ? "local" : ENV['WR_INTERFACE']
			
			if ! ENV['WR_DEBUG'].nil?
				Rake::Task["env:display"].reenable
				Rake::Task["env:display"].invoke
			end
			
			# Kill any previously running server
			Rake::Task["vnc:kill"].reenable
			Rake::Task["vnc:kill"].invoke
			Rake::Task["xvfb:kill"].reenable
			Rake::Task["xvfb:kill"].invoke
			# Start the VNC server
			Rake::Task["vnc:start"].reenable
			Rake::Task["vnc:start"].invoke
			
			# opt
			t.pattern = ENV["FILE"].nil? ? ["./tests/**/*_test.rb","./tests/*_test.rb"] : ENV["FILE"]
			t.rspec_opts = ['-f documentation', '--color']
			t.verbose = true
	end
	
	desc "Setup the fixtures for running HEADLESS and execute the tests. WR_DISPLAY=:5 will override the DISPLAY used."
	RSpec::Core::RakeTask.new(:headless) do |t|
	
			ENV['DISPLAY'] = ENV['WR_DISPLAY'] = ENV['WR_DISPLAY'].nil? ? ':5' : ENV['WR_DISPLAY']
			ENV['WR_INTERFACE'] = ENV['WR_INTERFACE'].nil? ? "local" : ENV['WR_INTERFACE']
			
			if ! ENV['WR_DEBUG'].nil?
				Rake::Task["env:display"].reenable
				Rake::Task["env:display"].invoke
			end
			
			# Kill any previously running server
			Rake::Task["vnc:kill"].reenable
			Rake::Task["vnc:kill"].invoke
			Rake::Task["xvfb:kill"].reenable
			Rake::Task["xvfb:kill"].invoke
			
			# Start the Xvfb server
			Rake::Task["xvfb:start"].reenable
			Rake::Task["xvfb:start"].invoke			

			# Verify that Xvfb is running
			verify_environment
			
			t.pattern = [File.join( File.dirname(__FILE__), "../../home/tasks/#{ENV['FILENAME']}") ] 
			#t.pattern = @wrpattern
			t.rspec_opts = ['-f documentation', '--color']
			t.verbose = true			
			ENV
	end

	namespace :nofixtures do
	
		desc "SKIP the fixtures for running HEADED and execute the tests"
		RSpec::Core::RakeTask.new(:headed) do |t|
						
			ENV['DISPLAY'] = ENV['WR_DISPLAY'] = ENV['WR_DISPLAY'].nil? ? ':5' : ENV['WR_DISPLAY']
			ENV['WR_INTERFACE'] = ENV['WR_INTERFACE'].nil? ? "local" : ENV['WR_INTERFACE']
			
			if ! ENV['WR_DEBUG'].nil?
				Rake::Task["env:display"].reenable
				Rake::Task["env:display"].invoke
			end
			
			# opt
			t.rspec_opts = ['-f documentation', '--color']
			#t.pattern = ENV["FILE"].nil? ? ["./tests/**/*_test.rb","./tests/*_test.rb"] : ENV["FILE"]
			t.pattern = [File.join( File.dirname(__FILE__), "../../home/tasks/#{ENV['FILE']}") ]
			t.verbose = true
		end
		
		desc "SKIP the fixtures for running HEADLESS and execute the tests"
	  RSpec::Core::RakeTask.new(:headless) do |t|
			puts "display = " + ENV['DISPLAY']
			ENV['DISPLAY'] = ENV['WR_DISPLAY'] = ENV['WR_DISPLAY'].nil? ? ':5' : ENV['WR_DISPLAY']
			ENV['WR_INTERFACE'] = ENV['WR_INTERFACE'].nil? ? "local" : ENV['WR_INTERFACE']
			
			if ! ENV['WR_DEBUG'].nil?
				Rake::Task["env:display"].reenable
				Rake::Task["env:display"].invoke
			end	
			
			# opt
			t.pattern = ENV["FILE"].nil? ? ["./tests/**/*_test.rb","./tests/*_test.rb"] : ENV["FILE"]
			t.rspec_opts = ['-f documentation']
			t.verbose = true
		end	
	end
end

namespace :custom do

	RSpec::Core::RakeTask.new(:domaudit, :url, :username, :userpass) do |t, args|
		puts "Rakefile Args were: #{args}"
		puts "url:/t/t/t " + args['url']
		puts "username:/t/t/t" + args['username']
		puts "userpass:/t/t/t" + args['userpass']
		
		ENV['WR_URL'] = args['url']
		ENV['WR_USERNAME'] = args['username']
		ENV['WR_USERPASS'] = args['userpass']
					
		ENV['DISPLAY'] = ENV['WR_DISPLAY'] = ENV['WR_DISPLAY'].nil? ? ':5' : ENV['WR_DISPLAY']
		ENV['WR_INTERFACE'] = ENV['WR_INTERFACE'].nil? ? "local" : ENV['WR_INTERFACE']
		
		if ! ENV['WR_DEBUG'].nil?
			Rake::Task["env:display"].reenable
			Rake::Task["env:display"].invoke
		end
		
		# Kill any previously running server
		Rake::Task["vnc:kill"].reenable
		Rake::Task["vnc:kill"].invoke
		Rake::Task["xvfb:kill"].reenable
		Rake::Task["xvfb:kill"].invoke
		# Start the Xvfb server
		Rake::Task["xvfb:start"].reenable
		Rake::Task["xvfb:start"].invoke		
		
		# opt
		#t.rspec_opts = ['-f documentation', '--t ' + args['url'].to_s, '--color']#, '-tusername ' + args['username'], '-tuserpass ' + args['userpass']]
		t.rspec_opts = ['-f documentation', '--color']
		t.pattern = ENV["FILE"].nil? ? ["./tests/**/*_test.rb","./tests/*_test.rb"] : ENV["FILE"]
		t.verbose = true
	end
end

# RSpec::Core::RakeTask.new(:argtest, :url, :user) do |t, args|
	# puts "-------- Args were: #{args}"
# end

# load up garlic if it's here
# if File.directory?(File.join(File.dirname(__FILE__), 'garlic'))
  # require File.join(File.dirname(__FILE__), 'garlic/lib/garlic_tasks')
  # require File.join(File.dirname(__FILE__), 'garlic')
# end

# desc "clone the garlic repo (for running ci tasks)"
# task :get_garlic do
  # sh "git clone git://github.com/ianwhite/garlic.git garlic"
# end

# # Run all features or one file
# t.pattern = ENV["FILE"].blank? ? ["spec/features/*.rb","spec/features/**/*.rb"] : ENV["FILE"]

# # Make rspec pretty
# t.rspec_opts = ['-f documentation', '--color']

# namespace :bootstrap do
	# desc "start selenium server"
	# task :start do
		# %x{java -jar /home/packages/selenium-server-standalone-2.28.0.jar 2>/dev/null >/dev/null &}
	# end
# end

##########################################################################
# FIXTURES
##########################################################################

namespace :xvfb do

  desc "Xvfb break down"
  task :kill do
    # System call kill all Xvfb processes
    %x{killall Xvfb}
  end

  desc "Xvfb setup"
  task :start do
    # System call to start the server on display :99
		ENV['DISPLAY'] = ENV['WR_DISPLAY'] = ENV['WR_DISPLAY'].nil? ? ':5' : ENV['WR_DISPLAY']
    #%x{Xvfb #{ENV['WR_DISPLAY']} 2>/dev/null >/dev/null &}
	%x{Xvfb #{ENV['WR_DISPLAY']} -screen 0 1280x1024x16 2>/dev/null >/dev/null &}
  end
end

namespace :vnc do

  desc "vnc break down"
  task :kill do
    # System call kill vnc4server on display :99
		ENV['DISPLAY'] = ENV['WR_DISPLAY'] = ENV['WR_DISPLAY'].nil? ? ':5' : ENV['WR_DISPLAY']
    %x{vncserver -kill #{ENV['WR_DISPLAY']}}
  end
	
	desc "vnc setup"
  task :start do
    # This is what links the server to the test
    ENV['DISPLAY'] = ENV['WR_DISPLAY'] = ENV['WR_DISPLAY'].nil? ? ':5' : ENV['WR_DISPLAY']
    %x{vncserver #{ENV['WR_DISPLAY']} -geometry 1280x1024 2>/dev/null >/dev/null &}
  end
	
	desc "vnc firefox setup"
  task :firefox do
    # System call to start f irefox on display :99
    %x{firefox 2>/dev/null >/dev/null &}
  end

	task :killall do
		%x{killall Xtightvnc}
	end
end

namespace :env do

	desc "Display all internally set ENV variables"
	task :display do
		puts "---------------------------------------------"
		puts "DISPLAY:        \t\t #{ENV['DISPLAY']}"
		puts "WR_DISPLAY:     \t\t #{ENV['WR_DISPLAY']}"
		puts "FILE            \t\t #{ENV['FILE']}"
		puts "WR_INTERFACE:   \t\t #{ENV['WR_INTERFACE']}"
		puts "WR_RUNFILTER:   \t\t #{ENV['WR_RUNFILTER']}"
		puts "WR_FORCEDISPLAY:\t\t #{ENV['WR_FORCEDISPLAY']}"
		puts "WR_FFONLY:      \t\t #{ENV['WR_FFONLY']}"
		puts "WR_NOTUNNEL:    \t\t #{ENV['WR_NOTUNNEL']}"
		puts "---------------------------------------------"
	end
	
end
