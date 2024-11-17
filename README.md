# AutoSignSSH
AutoSignSSH is a powerful automation tool for setting up and managing OpenSSH Certificate Authorities (CAs). \
It simplifies SSH keys creation, certificate signing, validation, and revocation workflows, ensuring secure and efficient operations.

## Features
- Automates OpenSSH CA setup and certificate signing.\
- Key pair generation, including RSA, ECDSA[-SK] and ED25519[-SK]\
- Supports host and user certificate management.\
- Validates certificates against revocation lists.\
- Configurable extensions.\
- Bash-based, compatible with most Linux distributions.\
- Easy to use, requires no memorization of OpenSSH commands.

## Prerequisites
- Linux-based system (tested on Fedora).\
- OpenSSH version OpenSSH_9.8p1 or higher, and OpenSSL 3.2.2 or higher.\
- GNU bash, version 5.2.32.\
- Basic bash shell command, such as printf, echo, grep and cut.

## Installation
To install AutoSignSSH, simply clone the repository:\
`git clone https://github.com/cyber-sec-vanguard/AutoSignSSH`.\
Then, move into the downloaded directory: `cd AutoSignSSH`.\
Finally, make the script executable: `chmod +x autosignssh.sh`. You can run it now by executing `./autosignssh.sh` in your command line.

## Usage
AutoSignSSH is very easy to use, it'll walk you through the process, and ask you for inputs as it goes along. It's very user friendly, it doesn't even require any flags.\

## Reviews
Reviews and criticizm is welcomed.

## Contribution
Contributions are also welcomed. Please:
1- Fork the repository.
2- Create a new branch.
3- Commit changes.
4- Push the changes.
5- Open a pull request.

## License
This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.