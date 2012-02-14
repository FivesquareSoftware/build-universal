# utils.rb
# Created by John Clayton on 1/25/2010.
# Copyright 2010 Fivesquare Software, LLC. All rights reserved.
# Copyright 2011 Barnes & Noble. All rights reserved.

require 'yaml'
require 'ostruct'

class << YAML::DefaultResolver
	alias_method :_node_import, :node_import
	def node_import(node)
		o = _node_import(node)
		o.is_a?(Hash) ? ::OpenStruct.new(o) : o
	end
end

class Array
	def random
		self[Kernel.rand(self.size)]
	end
end



module Utils

	module Shell
		def self.do(command,&block)
			output = `#{command}`
			retval = $?
			if block_given?
				yield(retval == 0, output, command)
			end
		end
		
		def shell(command,&block)
			Shell.do(command,&block)
		end
	end
	
	module Interface
		def ask(question,options=[])
			prompt = "% #{question} (#{options.join('')}): "
			sync = STDOUT.sync
			begin
				STDOUT.sync = true
				print(prompt)
				STDIN.gets.chomp
			ensure
				STDOUT.sync = sync
			end
		end
	end	 
	
	module Configuration
		attr_accessor :config
		# Loads a yaml file by the given path
		# If can't find the file at the given path:
		#	 - tries ./file
		#	 - tries ~/file
		#	 - tries /etc/file
		#	 - tries ./config.yml
		#	 - gives up 
		def load_config(config_file, required=false)
			begin
				file_path = File.expand_path(config_file)
				
				if File.exist?(file_path)
					File.open(file_path) { |f| self.config = YAML.load(f) }
				else
					basename = File.basename(config_file)
					if File.exists?("./#{basename}")
						config_file = "./#{basename}"
					elsif File.exist?("~/#{basename}")
						config_file = "~/#{basename}"
					elsif File.exist?("/etc/#{basename}")
						config_file = "/etc/#{basename}"
					elsif File.exist?("./config.yml")
						config_file = "./config.yml"
					elsif required
              raise "Could not locate config file #{config_file} anywhere"
					end

          # No file loaded, and require is false, load new file or create empty config
          file_path = File.expand_path(config_file)						 
          if File.exist?(file_path)
            File.open(file_path) { |f| self.config = YAML.load(f) }
          else
						puts "Not loading #{config_file}"
            self.config = OpenStruct.new
          end
				end
				file_path
			rescue
				raise	 "#{file_path} did not load properly (#{$!})"
			end		 
		end
	end
	
	
end