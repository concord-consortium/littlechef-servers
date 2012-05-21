To use this repository you need two tools: littlechef and librarian-chef

### Setup environment to work with an existing Server

Install littlechef

    pip install littlechef
    
Install librarian-chef

    rvm --rvmrc --create use 1.9.3@genigames-servers
    gem install librarian
    
Run initial librarian install

    librarian-chef install

Setup the `auth.cfg` file to know about your genigames.pem file.

### Updating the Server

To add a new recipe or attribute to one of the servers, you edit the `nodes/SERVER_NAME.json` file, then run

    fix node:SERVER_NAME

If you need to use an additional cookbook, edit the file `Cheffile` then run

    librarian-chef install

### Setup a new lab.server

1.  Spin up an ubuntu lucid server (could be AWS or could be elsewhere)
   
    If you are using AWS then use `ami-8e40e7e7` so step 2 can be skipped 

2.  Install ChefSolo

        fix node:$HOSTNAME_OF_SERVER deploy_chef

3.  Install node.server
        
        fix node:$HOSTNAME_OF_SERVER role:node-server

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


### TODO

Fix the way nodejs is installing the apt repository so we don't need to run apt-get update ourselves

Separate out the couchdb from package installation code into its own recipe, look around for other couch
cookbooks to see if anyone wants this as an option.