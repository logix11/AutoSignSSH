#!/bin/bash

# Exit codes
SSH_ERROR=1
PATH_ERROR=2
ENVERR=3
PERMS_ERROR=4
CD_ERROR=5
SED_ERROR=6
#UNKNOWN_ERROR=7

# Define color variables
BLUE='\033[97;44m'      # Dark Blue background, white text
RED='\033[41m'       # Red background
YELLOW='\033[48;5;214m' # Yellow background, dark text
GREEN='\033[42m'		# Green background and white foreground
RESET='\033[0m'      # Reset to default

INFO="${BLUE}[ INFO ]${RESET}"
ERROR="${RED}[ ERROR ]${RESET}"
WARNING="${YELLOW}[ WARNING ]${RESET}"
SUCCESS="${GREEN}${BLACK}[ SUCCESS ]${RESET}"  # Green background, black text


establish(){
	echo -e "${INFO}	The script will establish the CA in this location, proceed?"
	local choice
	# This loop is to ensure that the user either enters 'Y', 'y', 'N' or 'n'.
	while : ; do
		read -rp "		Your input [Y/n] :: " choice
		if [[ $choice == "n" || $choice == "N" ]] ; then # Wrong directory
			echo -e "${WARNING}	Wrong directory, exiting..."
			exit $PATH_ERROR

		elif [[ $choice != "y" && $choice != "Y" ]] ; then # Invalid input
			echo -e "${WARNING}	Invalid input. Try again."

		else # right directory
			echo -e "${INFO}	Proceeding."
			break
		fi
	done
	sleep .5

	printf "\n--------------------------------------------------------------------------------\n"

	# Now into creating the needed directories, which are the following.
	echo -e "${INFO}	Creating directories and KRL file..."
	sleep .25
	if mkdir -p sshca/{ca,hosts,users} && touch sshca/krl.krl ; then
		echo -e "${SUCCESS}	DONE."
	else
		echo -e "${ERROR} Could not create directories or KRL file, exiting..."  
		exit $ENVERR
	fi
	echo -e "${INFO}	The created directories are:"
	echo -e "${INFO}		./sshca/	The root directory"
	echo -e "${INFO}		./sshca/ca/	Contains the CA's public and private keys."
	echo -e "${INFO}		./sshca/hosts/	Contains the hosts' certificates."
	echo -e "${INFO}		./sshca/users/	Contains the users' certificates."
	sleep .5

	echo -e "${INFO}	Setting access controls..."
	sleep .25
	if chmod 700 sshca && chmod 755 sshca/ca  ; then 
		echo -e "${SUCCESS}	DONE."
	else
		echo -e "${ERROR}	Could not set access controls, exiting..."
		exit $PERMS_ERROR
	fi

	# Attempt to change-directory to the created directories, if it fails, print
	# the error message, and exit.
	echo -e "${INFO}	Navigating to the direcotry..."
	sleep .25
	if cd sshca/ ; then 
		echo -e "${SUCCESS}	DONE."
	else
		echo -e "${ERROR}	Could not navigate to the created directories, exiting ..." 
		exit $CD_ERROR
	fi
	sleep .5

	printf "\n--------------------------------------------------------------------------------\n"

	# Now onto generating the private keys, one to sign on hosts' keys, and one 
	# to sign on users' keys
	echo -e "${INFO}	Generating a new private key for the hosts, this will prompt you for"
	echo -e "${INFO}	an encryption passphrase."
	echo -e "${INFO}	Remember the passphrase, or use a password manager."

	# Attempt to generate a key, if it fails, print the error message and exit.
	if ssh-keygen -a 16 -b 256 -f ca/ca_host_key -t ecdsa -Z aes128-gcm@openssh.com ; then 
		echo -e "${SUCCESS}	Generation of the hosts' key: DONE."
	else
		echo -e "${ERROR}	Could not generate CA's host signing keys, exiting..."
		exit $SSH_ERROR
	fi
	sleep .25

	echo -e "${INFO}	Setting access controls..."
	sleep .25
	if chmod 600 ca/ca_host_key && chmod 644 ca/ca_host_key.pub ; then 
		echo -e "${SUCCESS}	Setting access controls to the hosts' key: DONE."
	else
		echo -e "${ERROR}	Could not set access controls, exiting..."
		exit $PERMS_ERROR
	fi
	sleep .5

	printf "\n--------------------------------------------------------------------------------\n"

	echo -e "${INFO}	Generating a new private key for the users."
	sleep .25
	if ssh-keygen -a 16 -b 256 -f ca/ca_user_key -t ecdsa -Z aes128-gcm@openssh.com ; then
		echo -e "${SUCCESS}	Generation of the users' key: DONE."
	else
		echo -e "${ERROR}	Could not generate CA's user signing keys, exiting..."
		exit $SSH_ERROR
	fi

	echo -e "${INFO}	Setting access controls..."
	if chmod 600 ca/ca_user_key && chmod 644 ca/ca_user_key.pub ; then
		echo -e "${SUCCESS}	Setting access controls to the users' key: DONE."
	else
		echo -e "${ERROR}	: Could not set access controls, exiting..."
		exit $PERMS_ERROR
	fi	

	printf "\n--------------------------------------------------------------------------------\n"
	
	echo -e "${INFO}	Configuring the OpenSSH server..."
	echo -e "${INFO}	Enter the path to sshd_config configuration file (or leave it blank" 
	echo -e "${INFO}	to use the default path)"

	# EDITS START HERE
	echo -e "${INFO}	Configuring the OpenSSH server through a copy of the configuration file."
	if echo "
#	\$OpenBSD: sshd_config,v 1.105 2024/12/03 14:12:47 dtucker Exp $

# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# The strategy used for options in the default sshd_config shipped with
# OpenSSH is to specify options with their default value where
# possible, but leave them commented.  Uncommented options override the
# default value.

Port 22
AddressFamily	any
ListenAddress	0.0.0.0
ListenAddress	::

# Host keys


# Ciphers and keying
#RekeyLimit default none
# The defaults are ridiculous.
Ciphers	aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-cbc,aes192-cbc,aes256-cbc  
MACs	hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com,umac-64@openssh.com


# Logging
SyslogFacility	AUTH
LogLevel		INFO # Set to DEBUG{1,2,3} if need be

# Authentication:
LoginGraceTime			2m
PermitRootLogin			prohibit-password
StrictModes				yes
MaxAuthTries			6
MaxSessions				10
PubkeyAuthentication 	yes
# This is important in our configuration
TrustedUserCAKeys		$(pwd)/ca_user_key.pub

# The default is to check both .ssh/authorized_keys and .ssh/authorized_keys2
# but this is overridden so installations will only check .ssh/authorized_keys
#AuthorizedKeysFile	.ssh/authorized_keys
# NOTE: I have commented it because we'll use certificates instead of keys

#AuthorizedPrincipalsFile none

#AuthorizedKeysCommand none
#AuthorizedKeysCommandUser nobody

# For this to work you will also need host keys in /etc/ssh/ssh_known_hosts
#HostbasedAuthentication no
# Change to yes if you don't trust ~/.ssh/known_hosts for
# HostbasedAuthentication
#IgnoreUserKnownHosts no
# Don't read the user's ~/.rhosts and ~/.shosts files
#IgnoreRhosts yes

# To disable tunneled clear text passwords, change to \"no\" here!
PasswordAuthentication no
PermitEmptyPasswords no

# Change to \"no\" to disable keyboard-interactive authentication.  Depending on
# the system's configuration, this may involve passwords, challenge-response,
# one-time passwords or some combination of these and other methods.
# NOTE: AutoSignSSH MAY use OTPs from PAM GA and Passwords from PAM
KbdInteractiveAuthentication yes

AllowAgentForwarding	no # Defaults to yes
AllowTcpForwarding		yes # Defaults to yes
GatewayPorts no
X11Forwarding no
X11DisplayOffset 10
X11UseLocalhost yes
PermitTTY yes
PrintMotd yes
PrintLastLog yes
TCPKeepAlive yes
PermitUserEnvironment no
Compression delayed
ClientAliveInterval	20 # Defaults to 0
ClientAliveCountMax	3
UseDNS no
PidFile /var/run/sshd.pid
MaxStartups 10:30:100
PermitTunnel no
#ChrootDirectory none
VersionAddendum none

# no default banner path
#Banner none

# override default of no subsystems
Subsystem	sftp	/usr/libexec/sftp-server

# Example of overriding settings on a per-user basis
#Match User anoncvs
	#	X11Forwarding no
	#	AllowTcpForwarding no
	#	PermitTTY no
	#	ForceCommand cvs server" > sshd_config
	then
		echo -e "${SUCCESS}	The OpenSSH server has been set up."
	else
		echo -e "${ERROR} The OpenSSH server configuration failed, exiting..."
		exit $PERMS_ERROR
	fi
	# EDITS END HERE

	printf "\n--------------------------------------------------------------------------------\n"

	echo -e "${SUCCESS}	Configuring the OpenSSH client..."
	echo -e "${SUCCESS}	Enter the path to ssh_known_hosts file (or leave it blank to use the default path)"

	# This loop is to ensure that the input is a valid one.
	local ssh_path
	while : ; do
		read -rp "		Your input :: " ssh_path
		if [[ -z $ssh_path ]] ; then
			ssh_path="/etc/ssh/ssh_known_hosts"
			echo -e "${INFO}	Using default path..."
			break
		elif [[ ! -e "$ssh_path" ]] ; then
			echo -e "${WARNING}	Invalid path."
		else
			echo -e "${SUCCESS}	Understood"
			break
		fi
	done

	echo -e "${INFO}	Copying ssh_known_hosts file..."
	if cp "$ssh_path" ./ssh_known_hosts ; then
		echo -e "${INFO}	DONE"
	else
		echo -e "${ERROR}	Could not copy ssh_known_hosts, attempting to create a local one..."
		sleep .5
		if touch ./ssh_known_hosts ; then
			echo -e "${SUCCESS}	DONE"
		else
			echo -e "${ERROR}	Could not create ssh_known_hosts"
			exit $PERMS_ERROR
		fi
	fi
	sleep .5
	
	printf "\n--------------------------------------------------------------------------------\n"

	echo -e "${INFO}	Setting it to trust the CA..."
	local ca_host_key ; ca_host_key=$(<ca/ca_host_key.pub)
	read -rp "		Enter your CA's domain name (or * for any) :: " dn
	if echo "@cert-authority ($dn) ($ca_host_key)" >> ./ssh_known_hosts ; then
		echo -e "${SUCCESS}	DONE."
	else
		echo -e "${ERROR}	Could not edit on sshd_config, exiting..."
		exit $SED_ERROR
	fi

	echo -e "${INFO}	The setup has finished successfully, you can start signing and"
	echo -e "${INFO}	issuing certificates after the host and users receive their"
	echo -e "${INFO}	configuration files, i.e., the sshd_config and ssh_known_hosts"
	return 0
}