#!/usr/bin/env ruby

# build-universal.sh
# Created by John Clayton on 1/25/2010.
# Copyright 2010 Fivesquare Software, LLC. All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 
# 3. Neither the name of <#organization#> nor the names of its contributors may
#    be used to endorse or promote products derived from this software without
#    specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE ICONFACTORY BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require 'rubygems'
require 'optparse'
require 'ostruct'
require 'fileutils'

$: << File.dirname(__FILE__)
require 'utils'


class UniversalBuilder
	include ::Utils::Interface
	include ::Utils::Shell
	include ::Utils::Configuration
	include FileUtils
		
	attr_accessor :options
	
	def self.execute!
		new.execute!
	end
	
	def execute!
		load_config_file
		parse_opts!
		clean
		build
	end
	


	#----------------------------------------------------------------------------
	private
	
	
	## Actions
	
	def load_config_file
		cfile = load_config(File.join("build.yml"))

		# some sensible defaults 
		self.config.configurations ||= %w{Debug Release}
		self.config.sdks ||= %w{iphoneos iphonesimulator}
		self.config.xcodebuild ||= "/Developer/usr/bin/xcodebuild"
		self.config.build_dir ||= File.join(ENV['PWD'],'build')
    # self.config.parallelize = true unless self.config.marshal_dump.key?(:parallelize)
	end

	def parse_opts!
		self.options = OpenStruct.new
		
		opts = OptionParser.new do |opts|
			
			# Defaults are set to whatever is config, and can be overridden by options
			
			self.options.workspace = self.config.workspace
			self.options.scheme = self.config.scheme
			self.options.target = self.config.target
			self.options.configurations = self.config.configurations
			self.options.sdks = self.config.sdks
			self.options.xcodebuild = self.config.xcodebuild
			self.options.buildaction = self.config.buildaction
			self.options.build_dir = self.config.build_dir
			self.options.parallelize = self.config.parallelize
			self.options.archs = self.config.archs
			
			self.options.dry_run = false

			
			opts.banner = "Usage: #{$0} [options]"
			opts.on("-w", "--workspace WORKSPACE", "The workspace name to pass to xcodebuild. Defaults to #{self.config.workspace}.") do |opt|
				self.options.workspace = opt
			end
			opts.on("-h", "--scheme SCHEME", "The scheme to pass to xcodebuild. Defaults to #{self.config.scheme}.") do |opt|
				self.options.scheme = opt
			end
			opts.on("-t", "--target TARGET", "The target to pass to xcodebuild. Defaults to #{self.config.target}.") do |opt|
				self.options.target = opt
			end
			opts.on("-c", "--configurations a,b,c", Array, "The build configurations to pass to xcodebuild. Defaults to #{self.config.configurations}.") do |opt|
				self.options.configurations = opt
			end
			opts.on("-s", "--sdks a,b,c", Array, "The sdk to pass to xcodebuild. Defaults to nil in which case the base sdk of the project is used.") do |opt|
				self.options.sdks = opt
			end
			opts.on("-x", "--xcodebuild XCODEBUILD", "The location of the 'xcodebuild' command to invoke. Defaults to #{self.config.xcodebuild}.") do |opt|
				self.options.xcodebuild = opt
			end
			opts.on("-b", "--build-dir BUILD_DIR", "The directory to place build products. Defaults to #{self.config.build_dir}.") do |opt|
				self.options.build_dir = opt
			end
      # opts.on("-p", "--[no]-parallelize", "Whether to run builds with multiple threads. Defaults to #{self.config.parallelize}.") do |opt|
      #   self.options.parallelize = opt
      # end
			opts.on("-d", "--dry-run", "Runs through the entire build process but does not actually build any products.") do |opt|
				self.options.dry_run = opt
			end
			# TODO: allow parsing arches from a string (YAML) format
		end
		opts.parse!
		if self.options.workspace
		  if self.options.scheme == nil
  			puts "For workspace builds, scheme cannot be nil"
  			puts opts
  			exit(1)
	    end
	  elsif self.options.target == nil
			puts "Either workspace+scheme or target must be set"
			puts opts
			exit(1)
		end
	end
	
	def clean
		rm_rf(self.options.build_dir)
		mkdir_p(self.options.build_dir)
	end
		
	def build
		log "* DRY RUN * Not building anything" if self.options.dry_run

		log "Build configuration:"
		self.config.marshal_dump.each{|k,v| log "\t#{k}: #{v.inspect}" }

		log "Building with options:"
		self.options.marshal_dump.each{|k,v| log "\t#{k}: #{v.inspect}" }
		
		self.options.configurations.each do |configuration|
			
			log "Building #{configuration} products"
			
			universal_dir = File.join(self.options.build_dir,"#{configuration}-universal")
			universal_product = File.join(universal_dir, product)
			
			mkdir_p(universal_dir)
			
			products = []
			self.options.sdks.each do |sdk|

				log "Building with SDK: #{sdk}"

				platform_name = sdk[/(iphone[^\d]+).*/,1]

				if self.options.workspace && self.options
					what_to_build_opt = "-workspace #{self.options.workspace} -scheme #{self.options.scheme}";
				else
					what_to_build_opt = "-target #{self.options.target}";
				end
				config_opt = "-configuration #{configuration}"
				sdk_opt = "-sdk #{sdk}"
        # parallelize_opt = self.options.parallelize ? "-parallelizeTargets" : "-jobs 1"
				
				# arches is an OpenStruct keyed by sdk with and array of values for that sdk, e.g. OpenStruct.new({ "iphoneos" => ["armv6", "armv7"] })
				archs = self.config.archs.send(platform_name.to_sym)
				log "Overriding default archs with #{archs.inspect}" if archs
				archs_opt = archs ? "ARCHS=\"#{archs.join(' ')}\"" : ''
				
				build_dir_opt = "BUILD_DIR=#{self.options.build_dir} BUILD_ROOT=#{self.options.build_dir}"

				cmd = "#{self.options.xcodebuild} #{what_to_build_opt} #{config_opt} #{sdk_opt} #{archs_opt} #{build_dir_opt} clean build"
				log "Issuing build command: #{cmd}"
				
				unless self.options.dry_run
					IO.popen(cmd) do |pipe|
						while(l = pipe.read(1024)) do
							print l
						end
					end
					error "Build failed" unless $? == 0
				end
				
				products << File.join(self.options.build_dir,"#{configuration}-#{platform_name}", product)
			end 
			lipo(products, universal_product)
		end
	end
	
		
	## Helpers
	
	def lipo(products, path)
		
		cmd = "lipo #{products.join(' ')} -create -output #{path}"
		log "Issuing lipo command: #{cmd}"
		unless self.options.dry_run
			system(cmd) 
			error "Build failed" unless $? == 0
		end
	end
		
	def product_name
		self.config.product_name || self.options.target || self.options.scheme
	end
		
	def product
		"lib#{product_name}.a"
	end
		
	def error(msg='')
		puts "Error: >>> #{msg}"
		exit 1
	end
	
	def log(msg)
		puts ">>> #{msg}"
	end
	
end

UniversalBuilder.execute!
