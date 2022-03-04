# --------------------------------------------------
# Script vault-assistant.sh
#
# Author: Dave Wunderlich  dave@scalesec.com; david.wunderlich@gmail.com
#
#---------------------------------------------------
# Supported OS:  Mac
# Command: ./vault-assistant.sh       
# called by automater app: open ~/vault/assistant/vault-assistant.command
#
#---------------------------------------------------
#!/bin/zsh

#debug
#set -vx

export VAULT_ASSISTANT_VERSION="0.0.1"

# Vault configuration files will be created at VAULT_ROOT
VAULT_ROOT=~/vault  

# --------------------------------------------------
# Functions:  Define shell functions
# --------------------------------------------------

set_colors () { # define colors for text UI
    export YELLOW='\x1B[33m'
    export BLUE='\x1B[34m'
    export BLACK='\x1B[30m'
    export DARK_GRAY='\x1B[90m'
    export LIGHT_GREEN='\x1B[92m'
    export RED='\x1B[31m'
    export COLOR_OFF='\x1B[0m'       # Text Reset
}

show_menu () { # displays menu
    clear

    echo "${LIGHT_GREEN}======================================================================="
    echo "Vault Assistant Version: $VAULT_ASSISTANT_VERSION"
    echo "======================================================================="

    show_vault_status

    echo " "
    echo "${BLUE}   S - Start Vault Server   ${DARK_GRAY}"$COLOR_OFF
    echo "${BLUE}   X - Stop Vault Server    ${DARK_GRAY}"$COLOR_OFF
    echo "${BLUE}   L - Seal Vault Server    ${DARK_GRAY}Lock / Seal vault"$COLOR_OFF
    echo "${BLUE}   U - Unseal Vault Server  ${DARK_GRAY}"$COLOR_OFF

    echo " "
    echo "${LIGHT_GREEN}   I - Initialize Vault     ${DARK_GRAY}Initializes vault after an install."$COLOR_OFF
    echo "${LIGHT_GREEN}   D - Delete Vault Data    ${DARK_GRAY}Delete current vault data."$COLOR_OFF
    echo ""
    echo "${RED}   H - Help                 ${DARK_GRAY}Show help."$COLOR_OFF
    echo "${RED}   E - Exit                 ${DARK_GRAY}Exit Vault Assistant Menu."$COLOR_OFF
    echo "${RED}   Q - Quit                 ${DARK_GRAY}Quit Vault and Exit Vault Assistant Menu."$COLOR_OFF
    echo " "

    read -p "Enter menu option S, X, L, U, I, D, H, Q, or E: " SELECTION_FROM_MENU
    # read sometimes give an error on mac osx 11  some other options
    #vared -p "Enter menu option S, X, L, U, I, D, H, Q, or E: " -c SELECTION_FROM_MENU
    #echo "Enter menu option S, X, L, U, I, D, H, Q, or E: "; read SELECTION_FROM_MENU

    export SELECTION_FROM_MENU

}

get_vault_version () {
    echo `vault --version`
}

get_vault_status () {
    if [[ `ps -ef | grep "vault/config.hcl" | grep -v grep` = "" ]]; then
        echo "Stopped"
   else
        echo "Running"
   fi
}

get_vault_seal_status () {
    if [[ $(get_vault_status) = "Running" ]]; then
        UNSEAL_STATUS=$(vault status | awk '/^Sealed/' | tr -s ' ' | cut -d ' ' -f2)
        if [[ $UNSEAL_STATUS = "false" ]]; then
            echo "Unsealed"
        else
            echo "Sealed"
        fi
    else
        echo "Unknown vault is stopped"
    fi
    
}

get_vault_root_token () {
    if [[ -f $VAULT_ROOT/local-root-token ]]; then
      ROOT_TOKEN=$(cat $VAULT_ROOT/local-root-token)
    else
      ROOT_TOKEN="Unknown"
    fi
    echo $ROOT_TOKEN
}

get_vault_key_share () {
    if [[ -f $VAULT_ROOT/local-unseal-key ]]; then
      KEY_SHARE=$(cat $VAULT_ROOT/local-unseal-key)
    else
      KEY_SHARE="Unknown"
    fi
    echo $KEY_SHARE
}

show_vault_status () {
 
    echo "${YELLOW}"
    echo "+----------------------------------------------------------------------"
    echo "| Server:   $(get_vault_status)"
    echo "| Sealed:   $(get_vault_seal_status)"
    echo "| Version:  $(get_vault_version)"
    echo "| Binary:   $(which vault)"
    echo "+----------------------------------------------------------------------"
    echo "| Root Token:  $(get_vault_root_token)"
    echo "| Key Share:   $(get_vault_key_share)"
    echo "| API:         http://127.0.0.1:8200/v1/"
    echo "| UI:          http://127.0.0.1:8200/ui/"
    echo "| Audit Log:   $VAULT_ROOT/vault-audit.log"
    echo "| Custom Plugins: $(get_custom_plugins)"
    echo "+---------------------------------------------------------------------"
    echo ""$COLOR_OFF
}
get_custom_plugins () {
    PLUGINS=`ls ~/vault/custom_plugin`
    echo "~/vault/custom_plugin : ${PLUGINS}"
}
start_vault () {
    if [[ $(get_vault_status) = "Stopped" ]]; then
        vault server -config=$VAULT_ROOT/config.hcl &
        sleep 5s

        #/bin/zsh -c "vault server -config=$VAULT_ROOT/config.hcl &"
        #sleep 5s
        echo "vault started"
    else
        echo "vault is already running"
    fi
}

stop_vault () {
    if [[ $(get_vault_status) = "Running" ]]; then
        PROCESS_ID=$(ps -ef | grep '[v]ault server' | awk '{print $2}')
        if [[ ! -z $PROCESS_ID ]]; then
            kill -9 $PROCESS_ID
            echo "vault stopped"
        else
            echo "could not find vault pid to stop"
        fi
    else 
        echo "vault is already stopped"
    fi

    stop_custom_plugin_processes
}

stop_custom_plugin_processes() {
    PROCESS_IDS=$(ps -ef | grep 'vault/custom_plugin' | awk '{print $2}')
    for PROCESS_ID in PROCESS_IDS
    do
        kill -9 $PROCESS_ID
    done
}

vault_seal () {
    if [[ $(get_vault_status) = "Running" ]]; then
        vault operator seal
    else
        echo "cant seal vault is not running"
    fi

}

vault_unseal () {
    if [[ $(get_vault_status) = "Running" ]]; then
        UNSEAL_KEY=`cat $VAULT_ROOT/local-unseal-key`
        vault operator unseal $UNSEAL_KEY
    else
        echo "cant unseal vault is not running"
    fi
}

vault_init () {
    vault_stop
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

vault_delete () {
    vault_stop

    if [[ -d $VAULT_ROOT/data ]]; then
        rm -Rf $VAULT_ROOT/data
    fi

    mkdir $VAULT_ROOT/data
    chmod 777 $VAULT_ROOT/data

    vault_init
}

vault_help () {
    clear
    echo "${BLUE}"
    echo "+----------------------------------------------------------------------"
    echo " The Vault Assistent Application Menu helps you to manage a local "
    echo " Hashicorp open source version of HashiCorp Vault."
    echo " "
    echo " This assistant menu secript is located: "
    echo " $VAULT_ROOT/assistant/vault-assistant.command"
    echo " "
    echo " Once you have vault running you can interact with it from a command"
    echo " terminal."
    echo " "
    echo " HashiCorp documents: "
    echo " 1.   https://www.vaultproject.io/docs/index.html "
    echo " 2.   cli commands https://www.vaultproject.io/docs/commands "
    echo " 3.   api commands https://www.vaultproject.io/api"
    echo " "
    echo "+---------------------------------------------------------------------"
    echo ""
    echo "${RED}press enter to continue"$COLOR_OFF
    read
}

#
# loop and show menu until exit
#
LOOP_MENU="true"
while [[ $LOOP_MENU == "true" ]]; do
    set_colors
    show_menu

    case $SELECTION_FROM_MENU in
        [Ss] ) # start
            echo "start"
            start_vault
            #echo "$(start_vault)" <-- Doing this version caused the shell to hang
            #echo "$(vault_unseal)"
        ;;

        [Xx] ) # stop
            echo "stop"
            echo "$(stop_vault)"
        ;;

        [Ll] ) # lock/seal
            echo "lock/seal"
            echo "$(vault_seal)"
        ;;

        [Uu] ) # unlock / unseal
            echo "unlock/unseal"
            echo "$(vault_unseal)"
        ;;

        [Ii] ) #init valut
            echo "init"
            vault_init
        ;;

        [Dd] ) # Delete valut data
            echo "delete data"
            vault_delete
        ;;

        [Hh] ) # Help
            echo "help"
            vault_help
        ;;

        [Ee] ) # exit assistant
            clear
            echo "exit"
            LOOP_MENU="false"
            exit
        ;;

        [Qq] ) # quit
            echo "quit vault and exit"
            echo "$(vault_seal)"
            echo "$(vault_stop)"
            echo "exit"
            LOOP_MENU="false"
            exit
        ;;

        * ) # invalid option
            echo "option selected is not valid - press enter to try again"
            read
        ;;
    esac

done