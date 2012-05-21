To use this repository you need two tools: littlechef and librarian-chef

### Setup your environment

Install littlechef

    pip install littlechef
    
Install librarian-chef

    rvm --rvmrc --create use 1.9.3@littlechef-servers
    gem install librarian
    
Run initial librarian install

    librarian-chef install

Setup the `auth.cfg` file to know about your genigames.pem file.

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

Fix the way nodejs is installing the apt repository so we don't need to run apt-get update ourselves

Separate out the couchdb from package installation code into its own recipe, look around for other couch
cookbooks to see if anyone wants this as an option.