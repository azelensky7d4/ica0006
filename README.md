# **Andmesalvestustehnoloogiad - ICA0006**
Autorid (Grupp 11) - Alexander Zelenskiy, Otto Kaur Pappel, Kristjan Steinfeldt, Tõnis Lepp

## **Ülesanne**
1. Kasutades HP serverite ILO kaughaldusliidest seadistada laboris riistvara peale RAID grupp operatsioonisüsteemi jaoks, installida endale sobiv serveri operatsioonisüsteem (3 füüsilist serverit).
2. Serveritele paigaldada horisontaalselt skaleeruv tarkvara (CEPH, ScaleIO, Microsoft Storagespaces, MinIO, Lustre, LizardFS jms).
3. Installeerida terraformi kasutades virtuaalserver ülikooli laborisse.
4. Provisioneerida andmesalvestus pind virtuaalserverile üle IP võrgu (kas plokina, jagatud failisüsteemina või objektide salvestuskohana). Et muuta ülesanne realistlikumaks, panna seda pinda kasutama kas andmebaas või mingi veebirakendus. Veenduda süsteemi tõrkekindluses, lülitades välja suvaline füüsiline server.

Ülesande lahendamiseks kasutame skeemil näidatud ülesehitust:

![skeem](images/skeem.png)



## Ülesannete jaotamine
| Ülesanne                                                                             | Vastutav isik       |
|--------------------------------------------------------------------------------------|---------------------|
| [1. RAID seadistamine](#1-raid-seadistamine)                                         | Alexander Zelenskiy |
| [2. OS paigaldamine](#2-os-paigaldamine)                                             | Tõnis Lepp          |
| [3. Andmesalvestuspinna loomine](#3-andmesalvestuspinna-loomine)                     | Kristjan Steinfeldt |
| [4. Virtuaalserveri installeerimine](#4-virtuaalserveri-installeerimine)             | Alexander Zelenskiy |
| [5. Andmesalvestuspinna provisioneerimine](#5-andmesalvestuspinna-provisioneerimine) | Otto K. P.          |
| [6. Andmebaasi seadistamine](#6-andmebaasi-seadistamine)                             | Otto K. P.          |
| [7. Tõrkekindluse testimine](#7-tõrkekindluse-testimine)                             | Tõnis Lepp          |

## **Ressursid**
| Nimi           | ILO liidese IP | Serveri IP     |
|----------------|:--------------:|----------------|
| server1        | 192.168.185.7  | 192.168.185.27 |
| server2        | 192.168.185.8  | 192.168.185.28 |
| server3        | 192.168.185.9  | 192.168.185.29 |
| Virtuaalserver |       –        | 192.168.180.26 |

VM user: student

VM password: student1234

## Sisukord

1. [RAID seadistamine](#1-raid-seadistamine)
2. [OS paigaldamine](#2-os-paigaldamine)
3. [Andmesalvestuspinna loomine](#3-andmesalvestuspinna-loomine)
4. [Virtuaalserveri installeerimine](#4-virtuaalserveri-installeerimine)
5. [Andmesalvestuspinna provisioneerimine](#5-andmesalvestuspinna-provisioneerimine)
6. [Andmebaasi seadistamine](#6-andmebaasi-seadistamine)
7. [Tõrkekindluse testimine](#7-tõrkekindluse-testimine)

# **1. RAID seadistamine**

Et jõuda RAID konfigureerimise liideseni, tuleb alglaadimise ajal vajutada `F8`.
Eduka sooritamise korral tekib menüü, millest on vaja kohe väljuda:
![raid 1 samm](images/raid1.png)

Pärast akna sulgemist toimub RAID kontrolleri laadimisprotsess, ning avaneb menüü, kus valin `Create Logical Drive`:
![raid 2 samm](images/raid2.png)

Loogilise ketta loomise aknas valin füüsilised kettad, mida soovin RAID massiivi panna ning valin sobiva RAID taseme.
Kuna ülesande järgi on vaja saavutada maksimaalne kõrgkäideldavus, valin `RAID 1+0`:
![raid 3 samm](images/raid3.png)

Nüüd on loogiline ketas loodud. Kontrollin seda peamenüü `View Logical Drive` sektsiooni alt:
![raid 4 samm](images/raid4.png) 

Kordan seda protsessi kõikide meie grupile antud füüsiliste serverite peal. Protsessi lõpus igale masinale saab seadistatud
üks ketas ~300 GB mahuga, kuhu paigaldatakse OS, ning üks 1.8 TB mahuga, mida antakse CEPHile. 

# **2. OS paigaldamine**

Serveritele installisime operatsioonisüsteemiks Ubuntu server 24.04. Installides sai konfigureeritud serverid vastavatele staatilistele IP'dele.
Ubuntu installi eraldi ei dokumenteeri.

**Kõikidele serveritele sai loodud kasutaja:**

user: student

passwd: student1234

**Serverite nimed vastavalt järjekorrale**: server1, server2, server3

| Väli       |     Väärtus     |
|------------|:---------------:|
| IP aadress | 192.168.185.2x  |
| Subnet     |  255.255.252.0  |
| Gateway    | 192.168.187.254 |
| DNS        |  172.16.0.175   |

Serveritele installisime ka OpenSSH kasutades käsku:
```zsh
$ sudo apt install openssh-server
```
SSH'ga pääsevad serverile ligi kõik, kes on ülikooli võrgus.

# **3. Andmesalvestuspinna loomine**

1.Andmesalvestuspinna jaoks installime cephi eelvajadused igale serverile.

Esimese sammuna veendume et kettad on täiesti tühjad
```zsh
$ sudo sgdisk --zap-all /dev/sdb
$ sudo wipefs --all /dev/sdb
```
Ceph vajab kas dockerit või podmani, otsustasime dockeri installida.
```zsh
$ curl -fsSL https://get.docker.com -o get-docker.sh
$ sudo sh get-docker.sh
```

Pärast dockeri installimist kontrollime et lvm2 on installitud ja et kõik meie serverid on ntp serveriga sünkroonis
```zsh
$ sudo apt install lvm2
$ timedatectl status
```

2. CEPHADM
valime ühe serveri mis on meie cephi haldaja. Meie jaoks on see server1

server 1 root kasutajana teeme ssh võtmed ja saadame selle teistele serveritele
```zsh
$ su -
$ ssh-keygen
$ ssh-copy-id root@192.168.185.28
$ ssh-copy-id root@192.168.185.29
```

Tõmbame alla cephadm ja lisame uusima versiooni globaalse muutuja
```zsh
$ export CEPH_RELEASE=19.2.1
$ curl --silent --remote-name --location https://download.ceph.com/rpm-${CEPH_RELEASE}/el9/noarch/cephadm
$ chmod +x cephadm
$ ./cephadm add-repo --release squid
$ ./cephadm install
```

Lisame server1 cephadm haldajaks ja tõmbame alla ceph käsurea utiili
```zsh
$ cephadm bootstrap --mon-ip 192.168.185.27
$ cephadm install ceph-common
```

Eelmise sammu käigus lõi ceph uued ssh võtmed. lisame need teistesse serveritesse
```zsh
$ ssh-copy-id -f -i /etc/ceph/ceph.pub root@192.168.185.28
$ ssh-copy-id -f -i /etc/ceph/ceph.pub root@192.168.185.29
```

Lisame serverid 2 ja 3 ceph clusterisse
```zsh
$ ceph orch host add server2 192.168.185.28 --labels _admin
$ ceph orch host add server3 192.168.185.29 --labels _admin
```

Lisame kõik saadavalolevad kettad cephi haldamisele
```zsh
$ ceph orch apply osd --all-available-devices
```

Loome andmesalvestus volüümi
```zsh
$ ceph fs volume create cephfs
```

# **4. Virtuaalserveri installeerimine**

Et kasutada loodud andmesalvestuspinda, loon uue virtuaalmasina ülikooli laborisse, selleks kasutan Hashicorp Terraformi.
Terraform skripti jooksutan MacOS peal, seepärast leian [Terraformi allalaadimisjuhendit MacOS jaoks](https://developer.hashicorp.com/terraform/install?product_intent=terraform).
Jooksutan terminalis järgmised käsud:
```zsh
$ brew tap hashicorp/tap  # Add hashicorp repo to homebrew
$ brew install hashicorp/tap/terraform  # Install terraform using homebrew
```
Terraform saab süsteemile installeeritud. Kontrollin:
```zsh
$ terraform --version

# Output
Terraform v1.11.1
on darwin_arm64
```
Loon oma kodukataloogis uue kausta `~TerraformProjects/ica0006/` ning loon uue faili `main.tf`:
```zsh
$ mkdir -p ~TerraformProjects/ica0006
$ cd TerraformProjects/ica0006
$ touch main.tf
```
Failis [main.tf](files/main.tf) asub terraformi skript, mis loob ülikooli laborisse virtuaalmasina. Enne,
kui seda jooksutada, muudan selles failis `vsphere` provideris `user` ja `password` õigeks, ning samuti
`vsphere_virtual_machine.demo` ressursil muudan grupi numbrit. Nüüd on skript valmis, initsialiseerin terraformi olles
samas kaustas kus asub `main.tf` fail:
```zsh
$ terraform init

# Output
# <output omitted>
Terraform has been successfully initialized!
# <output omitted>

```
Järgmisena käivitan käsu `terraform plan` et kontrollida, et skript töötab nagu oodatud:
```zsh
$ terraform plan

# Output
# <output omitted>
Plan: 1 to add, 0 to change, 0 to destroy.
# <output omitted>
```
Terraform kavatseb luua ühe ressursi, `vsphere_virtual_machine.demo`. Nüüd teen käsu `terraform apply`, et rakendada
konfiguratsiooni:
```zsh
$ terraform apply --auto-approve  # apply config and auto approve

# Output
# <output omitted>
vsphere_virtual_machine.demo: Creating...
vsphere_virtual_machine.demo: Still creating... [10s elapsed]
vsphere_virtual_machine.demo: Still creating... [20s elapsed]
vsphere_virtual_machine.demo: Still creating... [30s elapsed]
vsphere_virtual_machine.demo: Still creating... [40s elapsed]
vsphere_virtual_machine.demo: Still creating... [50s elapsed]
vsphere_virtual_machine.demo: Creation complete after 56s [id=42167a95-ef8c-b846-db0f-f1e56a49a6e3]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```
Kontrollin, kas ressurss on loodud kasutades `terraform state list` käsu:
```zsh
$ terraform state list

# Output
data.vsphere_datacenter.dc
data.vsphere_datastore.datastore
data.vsphere_network.network
data.vsphere_resource_pool.pool
data.vsphere_virtual_machine.template
vsphere_virtual_machine.demo
```
Meid huvitab `vsphere_virtual_machine.demo`, meie loodud VM. Pärin selle ressurssi kohta rohkem infot käsu
`terraform state show vsphere_virtual_machine.demo` abil:
```zsh
$ terraform state show vsphere_virtual_machine.demo

# Output
resource "vsphere_virtual_machine" "demo" {
# <output omitted>
    default_ip_address                      = "192.168.180.26"
# <output omitted>
```
Käsu väljundist meid huvitab virtuaalserveri IP aadress, panen selle [ressurside tabelisse](#ressursid). Kontrollin, kas
server on üles SSH abil:

```zsh
$ ssh student@192.168.180.26
student@192.168.180.26`s password: # student1234

# Output
Welcome to Ubuntu 22.04.3 LTS (GNU/Linux 5.15.0-78-generic x86_64)
# <output omitted>

$ student@lab:~$
```
Kui ligipääs serverile on olemas, võib astuda järgmise sammu juurde.

# **5. Andmesalvestuspinna provisioneerimine**

Esmalt tuleb paigaldada vajalikud paketid:
```zsh
$ sudo apt install ceph ceph-common
```
Seejärel tuleb kopeerida konfiguratsioonifail ja võti server1-lt:
```zsh
$ scp root@192.168.185.27:/etc/ceph/ceph.conf /etc/ceph/ceph.conf
$ scp root@192.168.185.27:/etc/ceph/ceph.client.admin.keyring /etc/ceph/ceph.client.admin.keyring
```
ning viimaks mount'ida:
```zsh
$ sudo mount -t ceph 192.168.185.27:/ /mnt/cephfs -o name=admin,secret=<key> # <key> failist /etc/ceph/ceph.client.admin.keyring
$ echo "192.168.185.27:/ /mnt/cephfs ceph name=admin,secret=<key> 0 0" | sudo tee -a /etc/fstab # automaatne mount'imine taaskäivitamisel, <key> failist /etc/ceph/ceph.client.admin.keyring
```

# **6. Andmebaasi seadistamine**

Tuleb paigaldada MySQL server, luua `/mnt/cephfs/mysql` kataloog ning anda vajalikud õigused:
```zsh
$ sudo apt install mysql-server
$ sudo mkdir /mnt/cephfs/mysql
$ sudo chown mysql:mysql /mnt/cephfs/mysql
```

Siis muuta MySQL konfiguratsioonifaili, et MySQL kasutaks andmete jaoks `/mnt/cephfs/mysql`:
```zsh
$ sudo vim /etc/mysql/mysql.conf.d/mysqld.cnf
```
Muuta tuleb seda rida: `datadir = /mnt/cephfs/mysql`

Lisaks peab lisama faili `/etc/apparmor.d/usr.sbin.mysqld` read:
```zsh
/mnt/cephfs/mysql/ r,
/mnt/cephfs/mysql/** rwk,
```
kasutades selleks näiteks vim'i: `sudo vim /etc/apparmor.d/usr.sbin.mysqld`.
See tagab, et AppArmor ei blokeeri selles kaustas tegutsemist.

Seejärel tuleb profiil uuesti laadida:
```zsh
$ sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld
```

ning siis MySQL lähtestada ja restartida:
```zsh
$ sudo mysqld --initialize
$ sudo service mysql restart
```

Et sisse saada, tuleb vahetada ka root'i parool:
```zsh
$ sudo service mysqld stop
$ sudo mkdir -p /var/run/mysqld
$ sudo chown mysql:mysql /var/run/mysqld
$ sudo mysqld --skip-grant-tables &
$ sudo mysql -u root
> FLUSH PRIVILEGES;
> ALTER USER 'root'@'localhost' IDENTIFIED BY 'student1234';
> exit;
$ sudo killall -9 mysqld
$ sudo systemctl start mysql
$ sudo mysql -u root -p # pw: student1234
```

**Et panna andmebaasi kasutama [AGAMA](https://github.com/hudolejev/agama) rakendus _(inspireeritult IT infra ainest)_, tuleb installida vajalikud paketid:**
```zsh
sudo apt install nginx uwsgi uwsgi-plugin-python3 python3-flask-sqlalchemy python3-pymysql
```

Seejärel luua agama kasutaja, andmebaas, andmebaasikasutaja ning anda sellele vajalikud õigused:
```zsh
$ sudo adduser --system --no-create-home --group agama
$ sudo mysql -u root -p # pw: student1234 
> CREATE DATABASE agama;
> CREATE USER 'agama'@'localhost' IDENTIFIED BY 'student1234';
> GRANT ALL PRIVILEGES ON agama.* TO 'agama'@'localhost';
> FLUSH PRIVILEGES;
> exit;
```

Laadida alla ka rakenduse fail:
```zsh
sudo wget -O /opt/agama/agama.py https://raw.githubusercontent.com/hudolejev/agama/master/agama.py
```

Luua `/etc/uwsgi/apps-enabled/agama.ini`:
```zsh
[uwsgi]
chdir = /opt/agama
module = agama:app
env = AGAMA_DATABASE_URI=mysql+pymysql://env = AGAMA_DATABASE_URI=mysql+pymysql://agama:student1234@localhost/agama
plugins = python3
socket = 127.0.0.1:5000
uid = agama
```
ning piirata õiguseid:
```zsh
sudo chown agama:agama /etc/uwsgi/apps-enabled/agama.ini
sudo chmod 0600 /etc/uwsgi/apps-enabled/agama.ini
```
ja taaskäivitada uwsgi: `service uwsgi restart`

Nginx'i `default` konfiguratsioonifail `/etc/nginx/sites-enabled/default`:
```zsh
server {
        listen 80 default_server;
        server_name _;

        location / {
                uwsgi_pass localhost:5000;
                include uwsgi_params;
        }
}
```
ning: `service nginx restart`

Rakendus on kättesaadav ülikooli võrgus olles aadressilt http://192.168.180.26/.

# **7. Tõrkekindluse testimine**

Tõrkekindluse testimiseks simuleerime suvalise serveri riket sellega, et lülitame ta ootamatult välja. 
Server 2 välja lülitamise näitel on CEPH dashboardist näha, et kuigi tegu on tähelepanu vajava veaga, siis tööd ta veel ei katkesta. 
![Alerts](https://github.com/user-attachments/assets/2ecaebe4-968c-4437-a656-28cc3d9007e6)

Kahte serverit korraga ei saa välja enam lülitada, sest quorum vajab kahte serverit, et otsuseid langetada.

Testid tegin läbi iga serveriga üks haaval, kõigi puhul tulemus sama.

