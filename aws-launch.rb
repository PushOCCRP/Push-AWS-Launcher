# A script to launch a new AWS EC2 instance based on the latest AMI
# image of the Push Server.
#
# This does three things:
# 1.) launch AWS instance (default micro)
# 2.) Create an Elastic IP address and attach the instance
# 3.) Set up proper security groups

# To come
# - Log into server and start creation scripts

require 'aws-sdk'
require 'colorize'

# Loads in the AMI id we've set

AMI_ID_FILENAME = 'ami_id'

def load_ami
	ami_id = nil

	error "No file '#{AMI_ID_FILENAME}' found." if !File.file?(AMI_ID_FILENAME)

	File.open(AMI_ID_FILENAME, "r") do |f|
	  f.each_line do |line|
	  	if(!line.starts_with?("#") && line.length > 0)
		    # We may add other options 
		    if(line.starts_with("ami-"))
		    	ami_id = line.strip
		    end
		end
	  end
	end

	if(ami_id.nil?)
		error "Error: No AMI name set in the '#{AMI_ID_FILENAME}' file."
	end

	return ami_id
end


def error message continue=false
	puts message.red
	exit if !continue
end