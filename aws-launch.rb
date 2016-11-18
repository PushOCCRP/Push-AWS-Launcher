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
require 'highline/import'
require 'byebug'
require 'ruby-progressbar'

# constants
AMI_ID_FILENAME = 'ami_id'.freeze
CREDENTIALS_FILENAME = 'aws_credentials'.freeze

class PushManagement
  # Prompts for information and creates Client object for AWS
  @ec2_client = nil

  def client
    # If a client is already created, return it
    return @ec2_client if !@ec2_client.nil?

    credentials = load_credentials

    @ec2_client = Aws::EC2::Client.new(
      region: credentials[:aws_region],
        access_key_id: credentials[:aws_access_key_id],
      secret_access_key: credentials[:aws_secret_access_key]
    )

    # Here we test if it's created correctly
    # Run a really basic command see if it errors out
    begin
      @ec2_client.describe_vpcs
    rescue Exception => e
      error "Could not successfully log into AWS with the credentials provided\nError: #{e}"
    end

    return @ec2_client
  end

  # Loads in the AMI id we've set
  def load_ami
    ami_id = nil

    error "No file '#{AMI_ID_FILENAME}' found." if !File.file?(AMI_ID_FILENAME)

    File.open(AMI_ID_FILENAME, "r") do |f|
      f.each_line do |line|
        if(!line.start_with?("#") && line.length > 0)
          # We may add other options 
          if(line.start_with?("ami-"))
            ami_id = line.strip
          end
      end
      end
    end

    error "Error: No AMI name set in the '#{AMI_ID_FILENAME}' file." if ami_id.nil?

    return ami_id
  end

  def load_credentials
    region = nil
    access_key_id = nil
    secret_access_key = nil

    # Load in the credentials from the aws_credentials file
    error "No file '#{CREDENTIALS_FILENAME}' found." if !File.file?(CREDENTIALS_FILENAME)

    File.open(CREDENTIALS_FILENAME, "r") do |f|
      f.each_line do |line|
        if(!line.start_with?("#") && line.length > 0)
          # We may add other options 
          if(line.start_with?("aws_region="))
            region = line.strip.gsub "aws_region=", ""
          end

          if(line.start_with?("aws_access_key_id="))
            access_key_id = line.strip.gsub "aws_access_key_id=", ""
          end

          if(line.start_with?("aws_secret_access_key="))
            secret_access_key = line.strip.gsub "aws_secret_access_key=", ""
          end
      end
      end
    end

    if(region.nil?)
      error "Error: No AWS region name 'region_name=' set in the '#{CREDENTIALS_FILENAME}' file."
    end

    if(access_key_id.nil?)
      error "Error: No AWS access key id 'aws_access_key_id=' set in the '#{CREDENTIALS_FILENAME}' file."
    end

    if(secret_access_key.nil?)
      error "Error: No AWS secret access key 'aws_secret_access_key=' set in the '#{CREDENTIALS_FILENAME}' file."
    end

    return {aws_region: region, 
        aws_access_key_id: access_key_id, 
        aws_secret_access_key: secret_access_key}
  end

  # Start an EC2 instance using the provided AMI
  # If none is provided it starts an empty Ubuntu 16.0 image
  def spin_up_instance ami_name, vpc_id, key_name, security_group_id, subnet_id, instance_type = "t2.micro"
    resp = client.run_instances({
                                  dry_run: false,
                                  image_id: ami_name, # required
                                  min_count: 1, # required
                                  max_count: 1, # required
                                  key_name: key_name,
                                  instance_type: instance_type, # accepts t1.micro, t2.nano, t2.micro, t2.small, t2.medium, t2.large, m1.small, m1.medium, m1.large, m1.xlarge, m3.medium, m3.large, m3.xlarge, m3.2xlarge, m4.large, m4.xlarge, m4.2xlarge, m4.4xlarge, m4.10xlarge, m4.16xlarge, m2.xlarge, m2.2xlarge, m2.4xlarge, cr1.8xlarge, r3.large, r3.xlarge, r3.2xlarge, r3.4xlarge, r3.8xlarge, x1.16xlarge, x1.32xlarge, i2.xlarge, i2.2xlarge, i2.4xlarge, i2.8xlarge, hi1.4xlarge, hs1.8xlarge, c1.medium, c1.xlarge, c3.large, c3.xlarge, c3.2xlarge, c3.4xlarge, c3.8xlarge, c4.large, c4.xlarge, c4.2xlarge, c4.4xlarge, c4.8xlarge, cc1.4xlarge, cc2.8xlarge, g2.2xlarge, g2.8xlarge, cg1.4xlarge, p2.xlarge, p2.8xlarge, p2.16xlarge, d2.xlarge, d2.2xlarge, d2.4xlarge, d2.8xlarge
                                  monitoring: {
                                    enabled: true, # required
                                  },
                                  network_interfaces: [
                                    {
                                      subnet_id: subnet_id,
                                      groups: [security_group_id],
                                      device_index: 0,
                                      associate_public_ip_address: true
                                    }
                                  ],

                                  instance_initiated_shutdown_behavior: "stop", # accepts stop, terminate
                                })

    error "Error starting EC2 instance #{resp.inspect}" if resp.instances.nil? || resp.instances.size == 0

    return resp.instances[0]
  end

  def check_status_of_instance instance_id
    resp = client.describe_instance_status({
      instance_ids: [instance_id],
      include_all_instances: true
    })

    error "No instance found for id #{instance_id}" if resp.instance_statuses.size == 0

    return resp.instance_statuses[0].instance_state.name
  end

  def set_name_of_instance name, instance_id
    resp = client.create_tags({
      resources: [
        instance_id
      ],
      tags: [
        {
          key: 'Name',
          value: name
        }
      ]
     })

  end

  #Elastic IP

  def allocate_elastic_ip
    resp = client.allocate_address({
      domain: 'vpc'
    })

    say "Allocated IP Address " + resp.public_ip.green
    return resp
  end

  def associate_ip(allocation_id, instance_id)
    client.associate_address({
      allocation_id: allocation_id, 
      instance_id: instance_id
    })

    say "Successfully assoicated ip to instance"
  end  

  # Key generation
  def create_key_pair app_name
    key_name = "#{app_name}-push"
    begin
    resp = client.create_key_pair({
      key_name: key_name, 
      })	  	
    rescue Exception => e
      error "Error creating key file\n Error: #{e}" if !e.to_s.include?("already exists.")

      # Key already exists on server
      should_continue = ask "Key " + key_name.green + " already exists, should I just use this one? (Please make sure you have access to the key first) Yn"
    
    exit if should_continue.downcase.strip != "y"
  
    say "Continuing with already existing key: " + key_name.green
    return key_name	
    end

    File.write "#{key_name}.pem", resp.key_material
    say "Created keypair and saved at: " + File.expand_path(File.dirname(__FILE__)).blue + "/#{key_name}.pem".green

    return key_name
  end

  def create_security_group app_name, vpc
    group_name = "#{app_name}-push"
    begin
      resp = client.create_security_group({
        group_name: group_name,
        description: "Security group for #{group_name} push mobile app backend application",
        vpc_id: vpc
      })
    rescue Exception => e
      error "Error creating security group\n Error: #{e}" if !e.to_s.include?("already exists for VPC")

      # Security group already exists on server
      should_continue = ask("Security group " + "#{app_name}-push".green + " already exists, should I just use this one?")
      
      exit if should_continue.downcase.strip != "y"
    
      say "Continuing with already existing security group: " + group_name.green
      resp = client.describe_security_groups({
      })

      resp.security_groups.each do |security_group|
        if(security_group.group_name == group_name)
          return security_group.group_id
        end
      end

      error "Could not find security group\nThis is a fatal error and probably means a bug in the script."
    end
    say "Created security group with id: " + resp.group_id.green

    say "Setting proper ingress rules for security group..."
    set_security_group_rules resp.group_id

    return resp.group_id
  end

  def set_security_group_rules security_group_id
    ip_ranges = [{cidr_ip: "0.0.0.0/0"}] 

    resp = client.authorize_security_group_ingress({
      group_id: security_group_id,
      ip_permissions: [
        {
          ip_protocol: 'udp',
          from_port: 60_000,
          to_port: 61_000,
          ip_ranges: ip_ranges
        }, {
          ip_protocol: 'tcp',
          from_port: 22,
          to_port: 22,
          ip_ranges: ip_ranges
        }, {
          ip_protocol: 'tcp',
          from_port: 443,
          to_port: 443,
          ip_ranges: ip_ranges
        }
      ]
    })

    say "Successfully set security group ingress rules"
  end

  # Returns all VPC ids.
  def get_vpcs
    resp = client.describe_vpcs
    return resp.vpcs.map { |vpc| vpc.vpc_id }
  end

  def get_subnets vpc_id
    resp = client.describe_subnets({
      filters: [
        {
          name: "vpc-id", 
          values: [
            vpc_id, 
          ], 
        }, 
      ], 
    })
    return resp.subnets.map{ |subnet| subnet.subnet_id }
  end

  def error message, continue=false
    puts message.red
    exit if !continue
  end
end

###########

push_management = PushManagement.new

say "\n"
say "Creating new Amazon Instance for a Push Backend"
say "***********************************************"
say "\n"

app_name = nil
while(app_name == nil)
  temp_app_name = ask("What is the name of your app?")
  if(temp_app_name.length < 4)
    say "App name must be longer than four characters".blue
    next
  end
  if(temp_app_name.length > 10)
    say "App name cannot be longer than ten characters".blue
    next
  end


  app_name = temp_app_name.downcase.strip.gsub(" ", "_")
end

say "Using app name: " + app_name.green

say "\nGetting AMI name..."
ami_name = push_management.load_ami
say "Using AMI named: " + ami_name.green

say "\nGetting VPC names..."
vpcs = push_management.get_vpcs
vpc = nil
if vpcs.size > 1
  vpc = choose do |menu|
    menu.prompt = "Which VPC would you like to use?  "
    menu.choices(vpcs)
  end
else
  vpc = vpcs[0]
end

say "VPC name: " + vpc.green

say "\nGetting VPC subnets..."
subnets = push_management.get_subnets vpc
if subnets.size > 1
  subnet = choose do |menu|
    menu.prompt = "Which subnet would you like to use?  "
    subnets.each{ |subnet_choice| menu.choice(subnet_choice)}
  end
else
  subnet = subnets[0]
end

say "Subnet name: " + subnet.green


say "\nGenerating Key Pair..."
key_name = push_management.create_key_pair app_name

say "\nGenerating Security Group..."
security_group_id = push_management.create_security_group app_name, vpc

say "\nSpinning Up Instance..."

instance = push_management.spin_up_instance ami_name, vpc, key_name, security_group_id, subnet, "t2.micro"
say "Spun up instance successfully"

say "Waiting for instance to become active..."
progressbar = ProgressBar.create(starting_at: 20, total: nil)
while push_management.check_status_of_instance(instance.instance_id) != 'running'
  progressbar.increment
  sleep(0.4)
end

progressbar.finish
say "\n"

say "Instance came up successfully".green + "🎉🚀\n"

say "Setting name for instance to " + temp_app_name.green + " Push".green
push_management.set_name_of_instance(temp_app_name, instance.instance_id)

say "Allocating Elastic IP address..."
ip = push_management.allocate_elastic_ip

say "Associating IP address to instance..."
push_management.associate_ip(ip.allocation_id, instance.instance_id)

say '\nInformation'
say '*********************'
say 'Instance Name: '.yellow + temp_app_name
say 'Instance Id: '.yellow + instance.instance_id
say 'Elastic IP: '.yellow + ip.public_ip
say 'Key Name: '.yellow + key_name

say '\nNext Steps'
say '1.) Set your ssh key permissions to 400: ' + "sudo chmod 400 #{key_name}.pem".yellow
say '2.) Associate your public ip ' + ip.public_ip.green + ' with your DNS. A subdomain "A record" is usually best'
say '3.) Log into your sever: ' + "ssh ubuntu@#{ip.public_ip} -i #{key_name}.pem".yellow
say '    (or, better, use Mosh): ' + "mosh ubuntu@#{ip.public_ip} --ssh \"ssh -i #{key_name}.pem\"".yellow
say '4.) Follow the steps in the README ****INSERT LINK*****'

