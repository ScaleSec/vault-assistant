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
# 08/22/22
# Fixed bug with vault_stop should be stop_vault
# Added option to run vault in development mode
#
#---------------------------------------------------
#!/bin/zsh
 
#set -vx
 
export VAULT_ASSISTANT_VERSION="0.0.2"
 
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
   export BOLD_GREEN='\x1B[1;32m'
   export RED='\x1B[31m'
   export COLOR_OFF='\x1B[0m'       # Text Reset
}
 
show_menu () { # displays menu
   clear
 
   echo "${BOLD_GREEN}======================================================================="
   echo "Vault Assistant Version: $VAULT_ASSISTANT_VERSION"
   echo "======================================================================="$COLOR_OFF
 
   show_vault_status
 
   echo "${BLUE}   M - Toggle Dev Mode      ${DARK_GRAY}"$COLOR_OFF
   echo "${BLUE}   S - Start Vault Server   ${DARK_GRAY}"$COLOR_OFF
   echo "${BLUE}   X - Stop Vault Server    ${DARK_GRAY}"$COLOR_OFF
   echo "${BLUE}   L - Seal Vault Server    ${DARK_GRAY}Lock / Seal vault"$COLOR_OFF
   echo "${BLUE}   U - Unseal Vault Server  ${DARK_GRAY}"$COLOR_OFF
 
   echo " "
   echo "${BOLD_GREEN}   I - Initialize Vault     ${DARK_GRAY}Initializes vault after an install."$COLOR_OFF
   echo "${BOLD_GREEN}   D - Delete Vault Data    ${DARK_GRAY}Delete current vault data."$COLOR_OFF
   echo ""
   echo "${RED}   H - Help                 ${DARK_GRAY}Show help."$COLOR_OFF
   echo "${RED}   E - Exit                 ${DARK_GRAY}Exit Vault Assistant Menu."$COLOR_OFF
   echo "${RED}   Q - Quit                 ${DARK_GRAY}Quit Vault and Exit Vault Assistant Menu."$COLOR_OFF
   echo " "
 
   read -p "Enter menu option M, S, X, L, U, I, D, H, Q, or E: " SELECTION_FROM_MENU
 
   export SELECTION_FROM_MENU
 
}
 
get_vault_version () { # Get the version of vault that is installed
   echo `vault --version`
}
 
get_vault_status () { # Determine if vault is running or stopped
   FOUND_VAULT_COMMAND=`ps -ef | grep "vault server" | grep -v grep`
 
   if [[ $FOUND_VAULT_COMMAND = "" ]]; then
       echo "Stopped"
   else
       if [[ `echo $FOUND_VAULT_COMMAND | grep "\-dev"` = "" ]]; then
           echo "Running"
       else
           echo "Running in Dev Mode"
       fi
   fi
}
 
get_vault_seal_status () { # Determine if vault is sealed (locked) or unsealed (un-locked)
   RUNNING=`echo "$(get_vault_status)" | grep "Running"`
   #if [[ $(get_vault_status) = "Running" ]]; then
   if [[ $RUNNING != "" ]]; then
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
 
get_vault_root_token () { # get the root token for vault that is running on the local instance
   if [[ -f $VAULT_ROOT/local-root-token ]]; then
     ROOT_TOKEN=$(cat $VAULT_ROOT/local-root-token)
   else
     ROOT_TOKEN="Unknown"
   fi
   echo $ROOT_TOKEN
}
 
get_vault_key_share () { # get the key shard/share for the local instance
   if [[ -f $VAULT_ROOT/local-unseal-key ]]; then
     KEY_SHARE=$(cat $VAULT_ROOT/local-unseal-key)
   else
     KEY_SHARE="Unknown"
   fi
   echo $KEY_SHARE
}
 
get_vault_mode () {
   if [[ ! -f ~/vault/dev_mode.txt ]]; then
       echo "false" > ~/vault/dev_mode.txt
   fi
   echo `cat  ~/vault/dev_mode.txt`
}
toggle_dev_mode () {
   if [[ $(get_vault_mode) == "false" ]]; then
       echo "true" > ~/vault/dev_mode.txt
   else
       echo "false" > ~/vault/dev_mode.txt
   fi
}
 
show_vault_status () { # submenu to display the status of the valut local enviornment
   echo "${YELLOW}"$COLOR_OFF
   echo "${YELLOW}+----------------------------------------------------------------------"$COLOR_OFF
   echo "${YELLOW}| Server:   ${DARK_GRAY}$(get_vault_status)"$COLOR_OFF
   echo "${YELLOW}| Sealed:   ${DARK_GRAY}$(get_vault_seal_status)"$COLOR_OFF
   echo "${YELLOW}| Version:  ${DARK_GRAY}$(get_vault_version)"$COLOR_OFF
   echo "${YELLOW}| Binary:   ${DARK_GRAY}$(which vault)"$COLOR_OFF
   echo "${YELLOW}| Dev Mode: ${DARK_GRAY}$(get_vault_mode)"$COLOR_OFF
   echo "${YELLOW}+----------------------------------------------------------------------"$COLOR_OFF
   echo "${YELLOW}| Root Token:  ${DARK_GRAY}$(get_vault_root_token)"$COLOR_OFF
   echo "${YELLOW}| Key Share:   ${DARK_GRAY}$(get_vault_key_share)"$COLOR_OFF
   echo "${YELLOW}| API:         ${DARK_GRAY}http://127.0.0.1:8200/v1/"$COLOR_OFF
   echo "${YELLOW}| UI:          ${DARK_GRAY}http://127.0.0.1:8200/ui/"$COLOR_OFF
   echo "${YELLOW}| Audit Log:   ${DARK_GRAY}$VAULT_ROOT/vault-audit.log"$COLOR_OFF
   echo "${YELLOW}| Custom Plugin Dir: ${DARK_GRAY}$(get_custom_plugins)"$COLOR_OFF
   echo "${YELLOW}+---------------------------------------------------------------------"$COLOR_OFF
   echo ""$COLOR_OFF
}
get_custom_plugins () { # get a list of installed custom plugins in the custom plugin dier
   PLUGINS=`ls ~/vault/custom_plugin`
   echo "~/vault/custom_plugin : ${PLUGINS}"
}
start_vault () { # Start vault if it is not already running
   DEV_MODE=$(get_vault_mode)
 
   if [[ $(get_vault_status) = "Stopped" ]]; then
       if [[ $(cat  ~/vault/dev_mode.txt) == "false" ]]; then
           vault server -config=$VAULT_ROOT/config.hcl &
           sleep 5s  # Wait 5 seconds to give vault time to startup in its new thread
           echo "vault started"
       else
           vault server -dev -log-level="debug" &
           echo "vault started - DEVELOPMENT MODE"
       fi
      
   else
       echo "vault is already running"
   fi
}
 
stop_vault () { # Stop vault and any running custom plugin threads
   VRUNNING=`echo "$(get_vault_status)" | grep "Running"`
   #if [[ $(get_vault_status) = "Running" ]]; then
   if [[ $VRUNNING != "" ]]; then
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
 
stop_custom_plugin_processes() { # Stop any running custom plugin threads
   PROCESS_IDS=$(ps -ef | grep 'vault/custom_plugin' | awk '{print $2}')
   if [[ ! -z $PROCESS_IDS ]]; then
        for PROCESS_ID in PROCESS_IDS
        do
            kill -9 $PROCESS_ID
        done
   fi
}
 
vault_seal () { # Seal / Lock vault
   if [[ $(get_vault_status) = "Running" ]]; then
       vault operator seal
   else
       echo "cant seal vault is not running"
   fi
 
}
 
vault_unseal () { # Unsean / unlock vault
   if [[ $(get_vault_status) = "Running" ]]; then
       UNSEAL_KEY=`cat $VAULT_ROOT/local-unseal-key`
       vault operator unseal $UNSEAL_KEY
   else
       echo "cant unseal vault is not running"
   fi
}
 
vault_init () { # Initialze vault and save off the shard(s) and root token.
   vault_stop
   vault server -config=$VAULT_ROOT/config.hcl &
   sleep 5s
 
   # Note: We are saving the shard and root tokens to files for use in running vault locally.
   # in produciton you need these values but you would not want to persist them in local files
   # were doing it to support local develpment and running instance of vault.
 
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
 
vault_delete () { # Delete the current vault data and re-initialze vault
   vault_stop
 
   if [[ -d $VAULT_ROOT/data ]]; then
       rm -Rf $VAULT_ROOT/data
   fi
 
   mkdir $VAULT_ROOT/data
   chmod 777 $VAULT_ROOT/data
 
   vault_init
}
 
vault_help () { # Display help information
   clear
   echo "${BLUE}"
   echo "+----------------------------------------------------------------------"
   echo " The ScaleSec Vault Assistant Application Menu helps you to manage a "
   echo " local instance of the open source version of HashiCorp Vault."
   echo " "
   echo " This assistant menu secript is located: "
   echo " $VAULT_ROOT/assistant/vault-assistant.command"
   echo " "
   echo " Once you have vault running you can also interact with it from a command"
   echo " terminal."
   echo " "
   echo " HashiCorp documents: "
   echo " 1.   https://www.vaultproject.io/docs/index.html "
   echo " 2.   cli commands https://www.vaultproject.io/docs/commands "
   echo " 3.   api commands https://www.vaultproject.io/api"
   echo " "
   echo "${DARK_GRAY} ScaleSec Vault Assistant:"$COLOR_OFF
   echo "${BOLD_GREEN}      https://github.com/ScaleSec/vault-assistant"$COLOR_OFF
   echo "${BLUE}+---------------------------------------------------------------------"
   echo ""
   echo "${RED}press enter to continue"$COLOR_OFF
   read
}
 
#
#  Main loop to show and process the menu selection.
#  loop until exit is selected
#
LOOP_MENU="true"
while [[ $LOOP_MENU == "true" ]]; do
   set_colors
   show_menu
 
   case $SELECTION_FROM_MENU in
       [Mm] ) # start
           echo "mode"
           toggle_dev_mode
       ;;
       [Ss] ) # start
           echo "start"
           start_vault
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
           echo "$(stop_vault)"
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