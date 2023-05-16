# tak-server-rpm-installer

# TAK Server Pre-Script Steps

1. Download the .rpm file from [tak.gov](https://tak.gov/) (4.9 is the latest at this time)
2. Get [CentOS](http://isoredirect.centos.org/centos/7/isos/x86_64/) ISO (CentOS 7). Setup either a VM or install on baremetal.
   - Follow the prompts on the install, be sure to enable your networking on the install screen, and also set the install to be "infrastructure server".
   - Be sure to create an admin password and make the user you create an admin.
3. Install [FileZilla](https://filezilla-project.org/) or sftp or scp the `.rpm` file and `installTakServer.sh` script onto your server.

# Script Steps

The script will first update and upgrade your system by running:
```bash
sudo yum update -y && sudo yum upgrade -y
```

Then it will install the dependencies required for TAK Server
```bash
sudo yum install epel-release -y
sudo yum install java-11-openjdk-devel -y
sudo yum install patch -y
sudo yum install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm -y
```

## Install .rpm

Next the script will install the .rpm file.
The default value is `takserver-4.9-RELEASE23.noarch.rpm`

```bash
sudo yum install takserver-4.9-RELEASE23.noarch.rpm
```

## DB Script

After the .rpm is installed then the DB setup script will be executed
```bash
sudo /opt/tak/db-utils/takserver-setup-db.sh
```
## Reload Service

After the db setup script is complete, the systemctl deamon can be reloaded

```bash
sudo systemctl daemon-reload
```

Then TAK Server will be enabled to start at boot

```bash
sudo systemctl enable takserver
````
## Certificates

The script will prompt you for the following variables

```bash
export STATE=<state>
export CITY=<city>
export ORGANIZATION=<my-organizaton>
export ORGANIZATIONAL_UNIT=<my-unit>
``` 

Then it'll create the CA, a server cert, a user cert, and an admin cert
```bash
./makeRootCa.sh
```
It will ask you to give a name for your CA: `example-name`


The script will then prompt how many certificates you want to generate. Default (3)

The 3 certs that are recommended are as follows:

`cert_type`: server or client

`cert_name`: takserver, admin, user, etc (note admin is required to access the Web UI)
```
server takserver
client user
client admin
```

After the certs have been created the TAK Server service will be restarted. There is currently a 60 second sleep in the script to allow for the certs to reload. (You can tweak this if you have issues.)

```bash
systemctl restart takserver
```

Then it will authorize the `admin` cert

```bash
java -jar /opt/tak/utils/UserManager.jar certmod -A /opt/tak/certs/files/admin.pem
```

## Firewall
Lastly it'll setup the firewall with these ports open
```bash
sudo firewall-cmd --permanent --zone=public --add-port 8089/tcp
sudo firewall-cmd --permanent --zone=public --add-port 8443/tcp
sudo firewall-cmd --reload
```
You can manually verify by running this command:

```bash
sudo firewall-cmd --list-ports
```
The output should look like this
```
8089/tcp 8443/tcp
```


## Exiting
Lastly the script will print that the install completed successfully and then print the ip where you can find the server as well as the steps to get your certificate.
