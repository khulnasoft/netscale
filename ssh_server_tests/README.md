# Netscale SSH server smoke tests

Runs several tests in a docker container against a server that is started out of band of these tests.
Netscale token also needs to be retrieved out of band.
SSH server hostname and user need to be configured in a docker environment file


## Running tests

* Build netscale:
make netscale

* Start server:
sudo ./netscale tunnel --hostname HOSTNAME --ssh-server

* Fetch token: 
./netscale access login HOSTNAME

* Create docker env file:
echo "SSH_HOSTNAME=HOSTNAME\nSSH_USER=USERNAME\n" > ssh_server_tests/.env

* Run tests:
make test-ssh-server
