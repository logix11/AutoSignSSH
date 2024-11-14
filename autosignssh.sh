#!/bin/bash

# Exit codes
SSH_FAILURE=1
WRONG_PATH=2
FAILED_DIR_INIT=3
FAILED_CD=4
PERMS_ERROR=5
SED_ERROR=6

init(){
	printf "The script will establish the CA in this location, proceed? [Y/n] :: "

	while : ; do
		read -r choice
		if [[ $choice == "n" || $choice == "N" ]] ; then # Wrong directory
			echo "Wrong directory, exiting..."
			exit $WRONG_PATH

		elif [[ $choice != "y" && $choice != "Y" ]] ; then # Invalid input
			printf "Invalid input. Try again :: "

		else # right directory
			break
		fi
	done
	printf "Greate! Let's keep going

Task: creating directories..."
	if mkdir -p sshca/{ca,hosts,users}; 
	then
		echo "DONE."
	else
		echo "ERROR: Could not create directories, exitting..."  
		exit $FAILED_DIR_INIT
	fi
	echo "The created directories are:
ca/		Contains the CA's public and private keys.
hosts/	Contains the hosts' certificates.
users/	Contains the users' certificates.

--------------------------------------------------------------------------------
	"

	if cd sshca/ca; 
	then 
		echo "Navigating to the direcotry...DONE"
	else
		echo "ERROR: Could not navigate to the created directories, exiting ..." 
		exit $FAILED_CD
	fi

	echo "Generating a new private key for the hosts, this will prompt you for 
an encryption passphrase. 

Remember the passphrase, or use a password manager.
	"

	if ssh-keygen -a 16 -b 256 -f ca_host_key -t ecdsa -Z aes128-gcm@openssh.com;
	then 
		echo "Generation of the hosts' key: DONE."
	else
		echo "ERROR: Could not generate CA's host signing keys, exiting..."
		exit $SSH_FAILURE
	fi

	echo "
Setting access controls... This reuires the root password."

	if sudo chown root:root ca_host_key* && sudo chmod 600 ca_host_key;
	then 
		echo "Setting access controls to the hosts' key: DONE."
	else
		echo "ERROR: Could not set access controls, exiting..."
		exit $PERMS_ERROR
	fi

	echo "
--------------------------------------------------------------------------------

Generating a new private key for the users."

	if ssh-keygen -a 16 -b 256 -f ca_user_key -t ecdsa -Z aes128-gcm@openssh.com;
	then
		echo "Generation of the users' key: DONE."
	else
		echo "ERROR: Could not generate CA's user signing keys, exiting..."
		exit $SSH_FAILURE
	fi
	printf "
Setting access controls..."

	if sudo chown root:root ca_user_key* && sudo chmod 600 ca_user_key;
	then
		echo "Setting access controls to the users' key: DONE."
	else
		echo "ERROR: Could not set access controls, exiting..."
		exit $PERMS_ERROR
	fi	
	printf "
--------------------------------------------------------------------------------
	
Configuring the OpenSSH server...
Enter the path to sshd_config configuration file (or leave it blank to use the 
default path) :: " 
	while : ; do
		read -r sshd_path

		if [[ -z $sshd_path ]]; 
		then
			sshd_path="/etc/ssh/sshd_config"
			echo "Using default path..."
			break
		elif [[ ! -e "$sshd_path" ]];
		then
			echo "Invalid path. Try again"
		else
			echo "Understood"
			break
		fi
	done
	printf "Copying sshd_config configuration file..."
	
	if cp "$sshd_path" ../sshd_config;
	then
		echo DONE
	else
		echo "ERROR: could not copy sshd_config, exiting..."
		exit $WRONG_PATH
	fi
	pwd=$(pwd)
	printf "Setting it to trust the CA..."
	sed -i "1s/^/TrustedUserCAKeys\n/" ../sshd_config; # Prepend 
		# TrustedUserCAKeys to the beginning of the first line of that file, 
		# and theeeeeeeeeeeeeeeeeeeeeeeeeeeeeen replace it.
		# I could not reduce the complexity, sorry.
	if sed -i "/TrustedUserCAKeys/c\\TrustedUserCAKeys $(pwd)/ca_user_key" ../sshd_config;
	then
		echo "DONE.
Now put this file back to production directory."
	else
		echo "ERROR: could not edit on sshd_config, exiting..." 
		exit $SED_ERROR
	fi
	printf "
Configuring the OpenSSH client...
Enter the path to ssh_known_hosts file (or leave it blank to use the default 
path) :: "
	while : ; do
		read -r ssh_path

		if [[ -z $ssh_path ]]; 
		then
			ssh_path="/etc/ssh/ssh_known_hosts"
			echo "Using default path..."
			break
		elif [[ ! -e "$ssh_path" ]];
		then
			echo "Invalid path. Try again"
		else
			echo "Understood"
			break
		fi
	done
	printf "Copying sshd_ssh_known_hosts file..."
	if cp "$ssh_path" ../ssh_known_hosts;
	then
		echo "DONE"
	else
		printf "ERROR: could not copy sshd_config, attempting to create a local 
one..."
		if touch ../ssh_known_hosts;
		then
			echo DONE
		else
			echo ERROR: Could not create ssh_known_hosts
			exit $PERMS_ERROR
		fi
	fi

	printf "
--------------------------------------------------------------------------------

Setting it to trust the CA..."

	ca_host_key=$(<ca_host_key.pub)
	read -rp "Enter your CA's domain name :: " dn
	if sed -i "1s/^/@cert-authority ($dn) ($ca_host_key)" ../ssh_known_hosts;
	then
		echo "done"
	else
		echo "ERROR: could not edit on sshd_config, exiting..."
		exit $SED_ERROR
	fi

}

# main() {

echo "
   _____          __          _________.__                _________ _________ ___ ___  
  /  _  \  __ ___/  |_  ____ /   _____/|__| ____   ____  /   _____//   _____//   |   \\
 /  /_\  \|  |  \   __\\/  _ \\______  \ |  |/ ___\ /    \ \\_____  \ \\_____  \\/    ~    \\
/    |    \  |  /|  | (  <_> )        \|  / /_/  >   |  \/        \/        \    Y    /
\____|__  /____/ |__|  \____/_______  /|__\___  /|___|  /_______  /_______  /\___|_  / 
        \/                          \/   /_____/      \/        \/        \/       \/  

-------------------------------Hello and welcome!-------------------------------

This program will help you establish a local Secure Shell (SSH) Certificate 
Authority (CA) and manage it.

Ensure that OpenSSH is installed before running this script.
"

dnf search openssh &> /dev/null || (echo "No OpenSSH, exiting"; \
									exit $SSH_FAILURE)
if ! command -v ssh &> /dev/null; then
	echo "No OpenSSH, exiting"
	exit $SSH_FAILURE
fi

printf "It is indeed installed.

--------------------------------------------------------------------------------

Select an option.
[0] Exit.
[1] Establish a CA.
[2] Manage a CA

Your input :: " 
read -r choice

if [[ $choice == "1" ]];
then
	init
fi