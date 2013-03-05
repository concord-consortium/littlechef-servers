To use this repository you need two tools: littlechef and librarian-chef

### Setup your environment

Install littlechef

    pip install littlechef
    
Configure Ruby

    source ./.rvmrc
    bundle install --binstubs


Run initial librarian install

    librarian-chef install

Setup your .ssh/config file. It needs to know the correct identify file (pem) to use with the servers. 
Mine looks like this

	Host *.compute-1.amazonaws.com
	  User ubuntu
	  IdentityFile /Users/scytacki/Development/ec2/genigames.pem

This repository uses a submodule for the data_bags folder. It is a private repository named: chef-databags. If you are permitted to access this repository run this command

    git submodule update --init

### Setup a new lab.server

1.  Spin up an ubuntu lucid server (could be AWS or could be elsewhere)
   
    If you are using AWS then use `ami-8e40e7e7` so step 2 can be skipped 

2.  Install ChefSolo

        fix node:$HOSTNAME_OF_SERVER deploy_chef

3.  Install lab.server
        
        fix node:$HOSTNAME_OF_SERVER role:lab-server

### Adding new features to the lab.server configuration

1.  Spin up your own instance using the steps above. 

2.  Modify the necessary files to add the feature
    - `roles/lab-server.json` for changing an attribute or adding a recipe
    - `site-cookbooks/lab-server` for changing default deploy steps
    - `site-cookbooks/node-couch-webapp` for changing node and couch configuration
    - `Chefile` to use a new cookbook that isn't listed there see the "Add New Cookbook" section

3.  Update your instance

        fix node:$HOSTNAME_OF_SERVER

4.  Make sure it builds from scratch, redoing the "Setup a new lab.server" steps

5.  To put these features on the public server you have 2 options 
    -   copy the necessary data from the old server to the new one, and switch the ElasticIP to the new server
    -   update the public version (Note: it isn't part of this system yet so this command won't work yet)

            fix node:lab.dev.concord.org

### Setup a new WISE server

1.  Spin up an ec2 instance
    
        ./script/create_ec2.rb -s staging -p wise_project -n "my wise server"

2.  Install WISE server
        
        fix node:$HOSTNAME_OF_SERVER role:wise4

3.  Enjoy `thor wise *` commands.
    
        this wise:list
        thor wise:backup <instance_id>

### Adding new features to the lab.server configuration

1.  Spin up your own instance using the steps above. 

2.  Modify the necessary files to add the feature
    - `roles/lab-server.json` for changing an attribute or adding a recipe
    - `site-cookbooks/lab-server` for changing default deploy steps
    - `site-cookbooks/node-couch-webapp` for changing node and couch configuration
    - `Chefile` to use a new cookbook that isn't listed there see the "Add New Cookbook" section

3.  Update your instance

        fix node:$HOSTNAME_OF_SERVER

4.  Make sure it builds from scratch, redoing the "Setup a new lab.server" steps

5.  To put these features on the public server you have 2 options 
    -   copy the necessary data from the old server to the new one, and switch the ElasticIP to the new server
    -   update the public version (Note: it isn't part of this system yet so this command won't work yet)

            fix node:lab.dev.concord.org

### Adding a New Cookbook

There are 2 types of cookbooks supported: cookbooks and site-cookbooks.

*Cookbooks* are managed by librarian-chef. These are pulled from remote source. The source can be a github
repository, or a chef repository

You add a new one by modifying the Chefile so librarian-chef knows about the new cookbook. Then 
you run

    librarian-chef install

*Site-cookbooks* are local to this repository. In littlechef terms this "repository" is called a kitchen. 
Add a folder to the site-cookbooks folder. The folder needs the standard Chef cookbook format.


### TODO

When starting without ruby installed passenger doesn't install correctly because it is using the an ohai 
key for the location of ruby: :languages/ruby/ruby_bin, and that won't be configured correctly unless chef
is restarted. A couple of options are to make that be more dynamic, switch to rvm_passenger setup, or change the 
bootstrap scripts to build ruby from source

Improve the Indentify file managment. If we are going to use a single kitchen for all of our servers then we'll probably
want to have several pem files, and then all the developers would need to manage the mapping of all of those files.

Fix the way nodejs is installing the apt repository so we don't need to run apt-get update ourselves

Separate out the couchdb from package installation code into its own recipe, look around for other couch
cookbooks to see if anyone wants this as an option.

Make base image that contains the parts that are common when spinning up a new instance or testing code. This ought to 
contain:

- chef-solo
- ruby 1.9.3
- apache
- passenger
- git