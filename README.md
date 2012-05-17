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

### Setup a new server

Spin up server in Cloud

Install ChefSolo on the new server

    fix node:$HOSTNAME_OF_SERVER deploy_chef

Install apache on the server to get started

    fix node:$HOSTNAME_OF_SERVER recipe:apache2

This will then put a new json file in the nodes folder to record the recipies

Alternatively you can copy an an existing json file in the nodes folder, and give it the hostname then run

    fix node:$HOSTNAME_OF_SERVER

### TODO

Fix the way nodejs is installing the apt repository so we don't need to run apt-get update ourselves

Separate out the couchdb from package installation code into its own recipe, look around for other couch
cookbooks to see if anyone wants this as an option.