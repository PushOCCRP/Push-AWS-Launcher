# Push AWS
--------
A series of scripts to create and easily maintain Amazon AWS EC2 instances of Push Backend.

## Requirements
--------
* A *nix (including MacOS) system
* Ruby 2.1 or greater

## Setup
--------
The point of this is to make life much easier, since the AWS console is confusing, at best.

There are two steps for this part of the process.

1. Create AWS security credentials
2. Make sure your dependencies are up to date
3. Run generation scripts

### AWS Credentials
--------
*Note:* If you do not have an Amazon AWS account yet, you'll have to sign up here https://aws.amazon.com.
Don't worry, it's free to sign up.

1. Follow the steps that Amazon provides to generate and download keys at https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSGettingStartedGuide/AWSCredentials.html
2. Take note of the ```Access Key ID``` and ```Secret Access Key```
3. Make a copy of the ```aws_credentials_template``` in this repository and name the copy ```aws_credentials```
4. Edit the ```aws_credentials``` file, replacing the lines
   ```
   aws_access_key_id=xxxxxxxxxx
   aws_secret_access_key=xxxxxxxxxxxx
   ```
   with the values from step 2


### Ruby Dependencies
--------
*Note:* These scripts require Ruby 2.1 or greater. If you need to install Ruby or manage multiple versions [RVM](https://rvm.io/) is amazing and easy.

1. Verify that you have bundler installed ```bundle -v```
2. ```cd``` to the repository
3. Run ```bundle install``` to make sure all the dependencies are correct

### Run The Scripts
---------

1. ```ruby aws-launch.rb```
2. When prompted for the name, type in the full name of the organization i.e. "Kyiv Post", not "kyiv_post" or "kyivpost"

The script should handle literally everything else and at the end out put some more steps to follow

### Notes
---------

* The script automatically creates a new ssh key pair to access your server. Right now there's not way to set your own, but if you'd like that let me know.
* The instructions at the end give you samples on how to ssh into your sever. Really, you should move the key to your ~/.ssh folder for safe keeping.
* The public IP address is an Amazon Elastic IP, you usually only get ~5 per AWS account, so use them wisely.
* This automatically boots up a ```t2.micro``` instance. This sits on Amazon's 'free tier' and, in my experience is more than enough to handle moderate traffic. Feel free to upgrade it. 

### Contributing
--------
The Push project has been made under a Knight International Journalism Fellowship with the generous support of the International Center For Journalists and the Organzied Crime and Corruption Reporting Project.

Pull requests are awesome, please feel free to submit them.

If you have questions, please contact me.
Christopher Guess
[cguess@gmail.com](mailto:cguess@gmail.com)
[PGP Key](https://www.keybase.io/cguess)
