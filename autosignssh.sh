#!/bin/bash

# Exit codes
SSH_ERROR=1
#PATH_ERROR=2
#ENVERR=3
#PERMS_ERROR=4
#CD_ERROR=5
#SED_ERROR=6
#UNKNOWN_ERROR=7
#SSH_SIGERR=8
#SSH_CERTERR=9
#SSH_REVERR=10

# Importing
#source "$(dirname $0)/utils/gen_ecdsa.sh"
#source "$(dirname $0)/utils/gen_ecdsa.sh"
#source "$(dirname $0)/utils/gen_rsa.sh"
#source "$(dirname $0)/utils/gen_static.sh"
#source "$(dirname $0)/utils/generate.sh"
#source "$(dirname $0)/utils/print.sh"
#source "$(dirname $0)/utils/revoke.sh"
#source "$(dirname $0)/utils/sign_host.sh"
#source "$(dirname $0)/utils/sign_user.sh"
#source "$(dirname $0)/utils/verify.sh"

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
Authority (CA) and manage it."
sleep .5

# Check if OpenSSH is installed
echo -e "${INFO}	Ensuring that OpenSSH is installed before running this script..."
sleep 0.5
if ! command -v ssh &> /dev/null; then
	echo -e "${ERROR}	No OpenSSH, exiting..."
	exit $SSH_ERROR
	
fi
echo -e "${INFO}	DONE, it is indeed installed."

sleep .5

while :
do
	
	printf "\n--------------------------------------------------------------------------------\n"

	echo "		Select an option.
			[0] Exit.
			[1] Establish a CA.
			[2] Manage a CA"
	
	read -rp "			Your input :: " choice
	echo
	if [[ $choice == "0" ]] ; then
		echo -e "${WARNING}	Exiting..."
		exit 0
	elif [[ $choice == "1" ]] ; then
		echo -e "${INFO}	If you're running this program from its root directory, then copy this"
		echo -e "${INFO}	line into your ${HOME}/.bashrc. If not, then please, set the path"
		echo -e "${INFO}	accordingly, so that the program can easily find its root directory"
		echo -e "${INFO}	and other scrips."
		echo -e "${INFO}	The line ::"
		echo -e "${INFO}	export ASSH_ROOT=$(pwd)"
		sleep .5
		read -rp "Press enter when you're done "

		# sourcing the environment
		# shellcheck disable=SC1091
		source "$HOME/.bashrc"

		# sourcing the file that containts the method, then calling it.
		# shellcheck disable=SC1091
		source "${ASSH_ROOT}/utils/establish.sh"
		sleep .5
		establish
	elif [[ $choice == "2" ]] ; then
		# shellcheck disable=SC1091
		source "${ASSH_ROOT}/utils/manage.sh"
		manage
	else
		echo -e "${WARNING} Invalid input. Try again."		
	fi
done