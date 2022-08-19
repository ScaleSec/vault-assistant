# --------------------------------------------------
# Script vault-install.sh
#
# Author: Dave Wunderlich  dave@scalesec.com; david.wunderlich@gmail.com
#
#---------------------------------------------------
# Supported OS:  Mac
# Command: ./vault-install.sh       # Install the current version
# Command: ./vault-install.sh x.x.x # Install a version of vault
# x.x.x = version of vault located at https://releases.hashicorp.com/vault/
# IE: ./vault-install.sh 1.8.5      # Install 1.8.5 version of vault
# IE: ./vault-install.sh 1.8.5+ent  # Install 1.8.5+ent version of vault
#
# Install the latest version of vault and configure to run locally
# in a slead mode so it will retain history.  Running insall again
# will clear out all data and set the envrionent.
#
# Creates a helper vault application and install on dock
#
#---------------------------------------------------
#!/bin/zsh

# debug
#set -vx

# Check Shell to make sure it is ZSH else vault will have issues.
if [[ -z `echo $SHELL | grep "/bin/zsh"` ]]; then
    echo "Your default shell should be zsh for vault."
    echo "run the command: chsh -s /bin/zsh"
    echo "RESART you Mac and run the vault-install.sh script again"
    exit 99
fi

# Setup some variables:
USER_ID=`whoami`
CURRENT_DIR=`pwd`
PROFILE_FILE=".zprofile"

REQUESTED_VERSION=$1

# Vault configuration files will be created at VAULT_ROOT
VAULT_ROOT=~/vault  
# $VAULT_ROOT/data             # Directory location where vault will its store data
# $VAULT_ROOT/config.hcl       # Directory and configuration file for vault
# $VAULT_ROOT/local-root-token # Directory and file to store local root token
# $VAULT_ROOT/local-unseal-key # Directory and file to store local unseal token
# $VAULT_ROOT/custom_plugin    # Directory for custom vault plugins 

# FUTURE:  Chang the local-root-token and local-unseal-key to interaface
# with 1password command line tool
# https://support.1password.com/command-line-getting-started/
# the CLI does not integrate with the desktoptool yet.  this needs to happen first.


# --------------------------------------------------
# Functions:  Define shell functions
# --------------------------------------------------

# Setup the vault directories
vault_directory () {
    if [[ ! -d $VAULT_ROOT ]]; then
        mkdir $VAULT_ROOT
        chmod 777 $VAULT_ROOT
    fi

    # if the directory does not exist create else re-create
    if [[ -d $VAULT_ROOT/$1 ]]; then
        # remove 
        rm -rf $VAULT_ROOT/$1
    fi

    # Create
    mkdir $VAULT_ROOT/$1
    chmod 777 $VAULT_ROOT/$1
}

# Setup the config.hcl file
create_config_hcl () {
     # create the config.hcl file
    
cat <<EOFHCL > $VAULT_ROOT/config.hcl
disable_mlock    = true
ui               = true
plugin_directory = "$VAULT_ROOT/custom_plugin"
log_level        = "trace"

backend "file" {
path = "$VAULT_ROOT/data"
}

listener "tcp" {
address = "127.0.0.1:8200"
tls_disable = 1    
}

api_addr = "http://127.0.0.1:8200"
EOFHCL

echo "config.hcl"
cat $VAULT_ROOT/config.hcl
}

# get the version of vault reqeusted or the most current version of open source
set_vault_version () {
    if [[ -z $REQUESTED_VERSION ]]; then
        VERSION_LINE=`curl https://releases.hashicorp.com/vault/ | awk 'NR==67' | sed 's/+ent//'`
         OPEN_SOURCE_VERSION_S1=`echo $VERSION_LINE | sed 's/\+ent//g'`
        export OPEN_SOURCE_VERSION_S2=`echo $OPEN_SOURCE_VERSION_S1 | sed 's/\.hsm//g'`
        export VAULT_VERSION=`echo $OPEN_SOURCE_VERSION_S2 | cut -f2 -d_ | cut -f1 -d\<`
    else
        export VAULT_VERSION=$REQUESTED_VERSION
    fi

    echo "VAULT_VERSION=$VAULT_VERSION"
}

download_vault () { # download the current version of vault
    if [[ "arm64" == $(uname -m) ]]; then
        export VAULT_ZIP_NAME="vault_"$VAULT_VERSION"_darwin_arm64.zip"
    else
        export VAULT_ZIP_NAME="vault_"$VAULT_VERSION"_darwin_amd64.zip"
    fi

    if [[ ! -f ~/Downloads/$VAULT_ZIP_NAME ]]; then
        curl -o ~/Downloads/$VAULT_ZIP_NAME -k "https://releases.hashicorp.com/vault/"$VAULT_VERSION"/"$VAULT_ZIP_NAME
    fi
}

install_vault () { # Install vault
    if [[ ! -d /usr/local/vault ]]; then
        sudo mkdir /usr/local/vault
    fi
    
    sudo chown -R $USER_ID /usr/local/vault
    sudo chmod -R 775 /usr/local/vault
    
    unzip -o ~/Downloads/$VAULT_ZIP_NAME -d /usr/local/vault

    if [ ! -d /usr/local/bin ]; then
        sudo mkdir /usr/local/bin
    fi

    sudo ln -sf /usr/local/vault/vault /usr/local/bin/vault
    sudo chmod 775 /usr/local/bin/vault

    APP_NAME="vault"
    INSTALLED_APP_PATH="/usr/local/bin"

    #Tell apple gatekeeper that vault is ok to run.
    sudo spctl --add --label vault.label "/usr/local/bin/vault"
    sudo spctl --enable --label vault.label
    # disable the prompt about running an app from the internet
    sudo xattr -d -r com.apple.quarantine "/usr/local/bin/vault"

}

start_and_init_vault () { # Initilizse and start vault

    vault server -config=$VAULT_ROOT/config.hcl &
    sleep 5s

    vault operator init -key-threshold=1 -key-shares=1  2>&1 > $VAULT_ROOT/init.txt
    #FUTURE: have these goto 1Password
    awk '/^Unseal Key/' $VAULT_ROOT/init.txt | cut -d ' ' -f4 > $VAULT_ROOT/local-unseal-key
    awk '/^Initial Root Token/' $VAULT_ROOT/init.txt | cut -d ' ' -f4 > $VAULT_ROOT/local-root-token

    UNSEAL_KEY=`cat $VAULT_ROOT/local-unseal-key`
    vault operator unseal $UNSEAL_KEY

    export VAULT_TOKEN=`cat $VAULT_ROOT/local-root-token`

    #enable vault audit
    vault audit enable file file_path=$VAULT_ROOT/vault-audit.log log_raw=true
}

setup_user_profile () { # setup the users profile file 
    if [[ ! -e ~/$PROFILE_FILE ]]; then
        touch ~/$PROFILE_FILE
    fi

    # add VAULT_ADDR to user proife file
    ENV_VAULT_ADDR=$(cat ~/$PROFILE_FILE | grep "VAULT_ADDR")
    if [[ -z $ENV_VAULT_ADDR ]]; then
        echo "# HashiCorp Vault local environment variables:" >> ~/$PROFILE_FILE
        echo "export VAULT_ADDR='http://127.0.0.1:8200'" >> ~/$PROFILE_FILE
    else
        echo "VAULT_ADDR already set in ~/$PROFILE_FILE"
    fi

    # run the profile
    source ~/$PROFILE_FILE
}

install_vault_assistant () { # Install the ScaleSec Vault Assistant
    ./vault-assistant-install.sh
}

stop_vault () { # stop vault if it is running.
    PROCESS_ID=$(ps -ef | grep '[v]ault server' | awk '{print $2}')
    if [[ ! -z $PROCESS_ID ]]; then
        kill -9 $PROCESS_ID
    fi
}

# --------------------------------------------------
# install logic
# --------------------------------------------------

stop_vault
vault_directory data
vault_directory custom_plugin

create_config_hcl
set_vault_version
download_vault

install_vault
install_vault_assistant
setup_user_profile
start_and_init_vault
