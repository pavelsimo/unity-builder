#!/usr/bin/env bash

#
# Run steps
#
source /steps/set_extra_git_configs.sh
source /steps/set_gitcredential.sh

change_hostname_and_user() {
    # Check if the user provided a new hostname and username
    if [ $# -ne 2 ]; then
        echo "Usage: change_hostname_and_user <new_hostname> <new_username>"
        return 1
    fi

    NEW_HOSTNAME=$1
    NEW_USERNAME=$2

    # Validate the hostname
    if [[ ! $NEW_HOSTNAME =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "Error: Invalid hostname. Use only alphanumeric characters, dots, hyphens, and underscores."
        return 1
    fi

    # Validate the username
    if [[ ! $NEW_USERNAME =~ ^[a-zA-Z][a-zA-Z0-9._-]*$ ]]; then
        echo "Error: Invalid username. Must start with a letter and contain only alphanumeric characters, dots, hyphens, and underscores."
        return 1
    fi

    # Get the current username
    CURRENT_USERNAME=$(whoami)

    if [ "$CURRENT_USERNAME" == "root" ]; then
        echo "Error: Do not run this function as root."
        return 1
    fi

    echo "Changing hostname to '$NEW_HOSTNAME' and username to '$NEW_USERNAME'..."

    # Step 1: Update the hostname
    echo "Updating hostname..."
    if [ -f /etc/hostname ]; then
        echo "$NEW_HOSTNAME" | sudo tee /etc/hostname > /dev/null
        echo "/etc/hostname updated."
    else
        echo "Warning: /etc/hostname not found. Skipping."
    fi

    hostname "$NEW_HOSTNAME"
    echo "Kernel hostname updated."

    if [ -f /etc/hosts ]; then
        cp /etc/hosts /etc/hosts.bak
        echo "Backup of /etc/hosts created at /etc/hosts.bak"
        sed -i "s/127\.0\.1\.1.*/127.0.1.1 $NEW_HOSTNAME/" /etc/hosts
        echo "/etc/hosts updated."
    else
        echo "Warning: /etc/hosts not found. Skipping."
    fi

    if command -v hostnamectl &> /dev/null; then
        hostnamectl set-hostname "$NEW_HOSTNAME"
        echo "hostnamectl updated."
    else
        echo "Warning: hostnamectl not available. Skipping."
    fi

    # Step 2: Update the username
    echo "Updating username..."
    if id "$NEW_USERNAME" &> /dev/null; then
        echo "Error: Username '$NEW_USERNAME' already exists."
        return 1
    fi

    cp /etc/passwd /etc/passwd.bak
    cp /etc/shadow /etc/shadow.bak
    cp /etc/group /etc/group.bak
    echo "Backups of /etc/passwd, /etc/shadow, and /etc/group created."

    usermod -l "$NEW_USERNAME" "$CURRENT_USERNAME"
    usermod -d "/home/$NEW_USERNAME" -m "$NEW_USERNAME"
    groupmod -n "$NEW_USERNAME" "$CURRENT_USERNAME"
    echo "Username changed from '$CURRENT_USERNAME' to '$NEW_USERNAME'."

    if [ -d "/home/$NEW_USERNAME" ]; then
        echo "Updating configuration files in the home directory..."
        find "/home/$NEW_USERNAME" -type f -exec sudo sed -i "s/$CURRENT_USERNAME/$NEW_USERNAME/g" {} \;
        echo "Home directory updated."
    else
        echo "Warning: Home directory '/home/$NEW_USERNAME' not found. Skipping."
    fi

    if systemctl is-active systemd-hostnamed &> /dev/null; then
        systemctl restart systemd-hostnamed
        echo "systemd-hostnamed service restarted."
    fi

    echo "Hostname and username successfully updated!"
    echo "Re-login or reboot the system for changes to take full effect."
}


if [ "$SKIP_ACTIVATION" != "true" ]; then

  echo "#####################################"
  echo "#          BDC - Environment        #"
  echo "#####################################"

  export HOSTNAME=BE12-C-0008E
  export USER=SIP4BE

  change_hostname_and_user BE12-C-0008E SIP4BE
  export no_proxy=10.224.197.250,$no_proxy
  export NO_PROXY=10.224.197.250,$NO_PROXY
  
  printenv

  source /steps/activate.sh

  # If we didn't activate successfully, exit with the exit code from the activation step.
  if [[ $UNITY_EXIT_CODE -ne 0 ]]; then
    exit $UNITY_EXIT_CODE
  fi
else
  echo "Skipping activation"
fi

source /steps/build.sh

if [ "$SKIP_ACTIVATION" != "true" ]; then
  source /steps/return_license.sh
fi

#
# Instructions for debugging
#

if [[ $BUILD_EXIT_CODE -gt 0 ]]; then
echo ""
echo "###########################"
echo "#         Failure         #"
echo "###########################"
echo ""
echo "Please note that the exit code is not very descriptive."
echo "Most likely it will not help you solve the issue."
echo ""
echo "To find the reason for failure: please search for errors in the log above and check for annotations in the summary view."
echo ""
fi;

#
# Exit with code from the build step.
#

# Exiting su
exit $BUILD_EXIT_CODE
