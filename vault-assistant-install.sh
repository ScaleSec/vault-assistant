# --------------------------------------------------
# Script vault-assistant-install.sh
#
# Author: Dave Wunderlich  dave@scalesec.com; david.wunderlich@gmail.com
#
#---------------------------------------------------
# Supported OS:  Mac
# Command: ./vault-assistant-install.sh       # Install the vault assistant
#
# Creates a helper vault application and install on dock
#
# to change the app
# 1. unzip
# 2. open .app file with automator app
# 3. save
# 4. copy the vault-assistant-icon.icns to the .app directoy /Contents/Resources as ApplicationStub.icns
# 5. compess the .app for deployment as the new version
#
# adding a run apple script works to set the size but BigSir will not let me save
#
# tell application "Terminal"
#	set bounds of front window to {30, 30, 600, 550}
# end tell
# 
#---------------------------------------------------
#!/bin/zsh

# Vault configuration files will be created at VAULT_ROOT
VAULT_ROOT=~/vault  

if [[ ! -d $VAULT_ROOT/assistant ]]; then
    mkdir $VAULT_ROOT/assistant
    chmod 777 $VAULT_ROOT/assistant
fi

# cp ./vault-assistant-app/vault-assistant.sh ~/vault/assistant/vault-assistant.command
cp ./vault-assistant-app/vault-assistant.sh $VAULT_ROOT/assistant/vault-assistant.command
chmod 777 $VAULT_ROOT/assistant/vault-assistant.command

unzip -o ./vault-assistant-app/vault-assistant.app.zip -d $VAULT_ROOT/assistant
rm -R $VAULT_ROOT/assistant/__MACOSX

# configure the dock and gatekeeper


# if the app is already on the dock then add will put 2 there
# NOTE: the value in grep is the "bundle-identifier" and is set based on then name you "save as" in the automator
if [[ -z $(defaults read com.apple.dock persistent-apps | grep com.apple.automator.new-vault-assistant) ]]; then
    defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$VAULT_ROOT/assistant/vault-assistant.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
fi

# tell gatekeeper that the .app is ok
sudo spctl --add --label vault-assistant.app.label "$VAULT_ROOT/assistant/vault-assistant.app"
sudo spctl --enable --label vault-assistant.app.label
# tell gatekeeper that the .command is ok
sudo spctl --add --label vault-assistant.command.label "$VAULT_ROOT/assistant/vault-assistant.command"
sudo spctl --enable --label vault-assistant.command.label

sudo xattr -d -r com.apple.quarantine "$VAULT_ROOT/assistant/vault-assistant.app"
sudo xattr -d -r com.apple.quarantine "$VAULT_ROOT/assistant/vault-assistant.command"

# refresh the dock
killall Dock
