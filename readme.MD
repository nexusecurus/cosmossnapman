# <p align="center">Cosmos Ecosystem SNAPMaker</p> 
 <p align="center">powered by NexuSecurus&trade;</p> 


<div style="text-align:center">
    <img src="images/nexusecurus.png" alt="NexuSecurus">
</div>

<p align="center">
  <table>
    <tr>
      <th>Supported HW</th>
      <th>Target OS</th>
      <th>Code Stats</th>
      <th>Audience</th>
      <th>Type</th>
      <th>Dependencies</th>
      <th>License</th>
    </tr>
    <tr>
      <td><img src="https://img.shields.io/badge/Architecture-x86_64-blue?logo=intel&logoColor=white"></td>
      <td><img src="https://img.shields.io/badge/Ubuntu-OS-orange?logo=ubuntu"></td>
      <td><img src="https://img.shields.io/badge/Shell-Used-green?logo=bash"></td>
      <td><img src="https://img.shields.io/badge/Blockchain-%20Validators-%23197aaa?logo=linux&logoColor=white"></td>
      <td><img src="https://img.shields.io/badge/Menu-Based-brightyellow?logo=menu-framework"></td>
      <td><img src="https://img.shields.io/badge/Go-Latest%2B-blue?logo=go"></td>
      <td><img src="https://img.shields.io/badge/License-MIT-blue.svg"></td>
    </tr>
    <tr>
      <td><img src="https://img.shields.io/badge/ARM-Architecture-blue"></td>
      <td><img src="https://img.shields.io/badge/Linux-Used-yellow?logo=linux"></td>
      <td><img src="https://img.shields.io/badge/Markdown-Used-yellow?logo=markdown"></td>
      <td><img src="https://img.shields.io/badge/COSMOS-Ecosystem-purple"></td>
      <td><img src="https://img.shields.io/badge/Terminal-CLI-blue"></td>
    </tr>
  </table>
</p>


<br>

<br>

---

## <p align="center" > Project Description </p>
SNAPMaker simplifies the snapshot management process within the Cosmos Ecosystem. Operating locally, it requires pre-installed blockchain chains, even if they're not actively running. Once initiated, SNAPMaker systematically processes each chain, generating snapshots relying on external RPCs and P2P Endpoints, without the need for active node interaction. This unique approach allows a single machine to handle snapshot creation for multiple chains, without disrupting existing infrastructure. By automating tasks like resetting, syncing, compressing, and transferring blockchain data to remote servers, SNAPMaker ensures that users can effortlessly maintain current snapshots with minimal intervention. Moreover, its compatibility with tools like crontab enables scheduled execution, seamlessly integrating snapshot management into existing workflows.

<br>

---
<br>
<br>

## <p align="center" > Key Features </p>

#### **Cosmos Snapshot Maker**

<br>

**Automated Snapshot Creation**
    - Streamlines the process of creating blockchain snapshots by automating essential tasks such as resetting blockchain data, syncing to the latest block, compressing data, and copying snapshots, addressbook and genesis files to remote servers.

**Chain Configuration File**
    - Users can easily configure multiple blockchain networks within the chains.conf file, allowing SNAPMAKER to handle snapshots for various chains simultaneously.

**Remote Server Support**
    - Seamlessly integrates with remote servers, enabling users to store their blockchain snapshots securely off-site. It provides options to specify remote server details such as hostname, port, and SSH key for efficient snapshot transfer.

**JSON Metrics Generator**
    - Generates JSON metrics containing vital information about each snapshot, including chain name, snapshot size, checksum, sync status, and download URLs. These metrics facilitate easy tracking, auditing of snapshots and integrate their info with your website.

 
<br>

---
<br>
<br>



### <p align="center"><a name="table-of-contents"></a>Table of Contents</p>
<br>

- [Cosmos Ecosystem SNAPMaker](#cosmos-ecosystem-snapmaker)
  - [ Project Description ](#-project-description-)
  - [ Key Features ](#-key-features-)
      - [**Cosmos Snapshot Maker**](#cosmos-snapshot-maker)
    - [Table of Contents](#table-of-contents)
  - [ Program Requirements ](#-program-requirements-)
  - [ Installation Procedure ](#-installation-procedure-)
      - [1 - **Dependencies and Package Requirements**:](#1---dependencies-and-package-requirements)
      - [2 - **Clone the repository into your machine**:](#2---clone-the-repository-into-your-machine)
      - [3 - **Make the script file executable**:](#3---make-the-script-file-executable)
      - [4 - **Change /vars/chains.conf**](#4---change-varschainsconf)
  - [Additional information / Documentation **(MUST READ!!!)**](#additional-information--documentation-must-read)
  - [Usage](#usage)
  - [KNOWN Issues \& Bugs:](#known-issues--bugs)
  - [ About the Author ](#-about-the-author-)
  - [ Contribute To Our Effort ](#-contribute-to-our-effort-)


<br>

---
<br>
<br>


## <p align="center" > Program Requirements </p>
<br>

    - Ubuntu based Linux OS (We recommend Ubuntu Server Minimized, to avoid unnecessary software cluttering)
    - 2 vCPUs Minimum for Nodes (4 vCPUs recommended or more)
    - 6GB RAM Minimum for Nodes (we recommend 8GB RAM or more)
    - 60GB to 500GB Disk Space (Depending on Node Type, and Pruning Strategy)
    - Internet Connection ;
    - Installed NODE of the Chain you want to Snapshot in the local system.
    - A reachable RPC endpoint for the Chain
    - A reachable P2P endpoint for the Chain

<br>

## <p align="center" > Installation Procedure </p>
<br>

#### 1 - **Dependencies and Package Requirements**:  

  All dependencies and required packages for the correct execution of this program, will be installed when the script is executed for the first time.
    - ncat
    - curl
    - rsync
    - openssh-server


<br>

#### 2 - **Clone the repository into your machine**: 
Clone this repository to your machine using the following commands:

```bash
    git clone https://github.com/nexusecurus/cosmossnapmaker.git
```


<br>


#### 3 - **Make the script file executable**:
For the script to be executed, you must add execution permission to the file:

```bash
    chmod +x snapmaker.sh
```


<br>


#### 4 - **Change /vars/chains.conf**


        Open the [chains.conf](/vars/chains.conf) file under [vars](/vars/), and edit the VARIABLES that match your chain specifications, such as:

            Example:

            - CHAIN_NAME = The name of the Chain
            - HOME_DIR = Path where Chain files are located
            - STATE_SYNC_RPC = The URL of the RPC server you want to use.
            - STATE_SYNC_PEER = The NodeID@URL:PORT of the P2P server you want to use.
            - BIN_NAME = Binary name of the Chain.
            - SERVICE_NAME = The name of the service your chain is configured to use.
            - RPC_PORT = The RPC por of the localhost node, to verify when state reaches synced.

        Open the [remote.conf](/vars/remote.conf) file under [vars](/vars/), and edit the VARIABLES that match your REMOTE HOST info, such as:

            Example:
            
            - NOTIFY="username" -> Will notify user, to internal mail. If postfix is installed along with proper ALIASES and SMTP_HEADERS, variable can be an email.
            - DEST_DIR="/var/www/snapshots.nexusecurus.com/public_html" -> Folder location where snapshots will copied to.
            - REMOTE_HOST="username@hostname" -> Can be username@hostname, username@ip or if you want to copy files to local filesystem use username@localhost.
            - SSH_KEY="~/.ssh/ssh_private-key" -> SSH Private Key to access REMOTE_HOST, if not configured, delete variable content.
            - REMOTE_SSH_PORT="22" -> SSH Port configured on the target system.


<br>

---

<br>


## Additional information / Documentation **(MUST READ!!!)**
<br>
This section contains crucial information on what files need to be present for the program to work, in case you dont want to clone the full repo. 

<br>

The main program file is [snapmaker.sh](/snapmaker.sh), but it will not run if [vars](/vars/) folder is not present in the same directory, along with [chains.conf](/vars/chains.conf), [remote.conf](/vars/remote.conf) and [requirements.txt](/vars/requirements.txt) files.


---

<br>


## Usage
<br>

**Directly on Terminal**

After cloning the repository and making the program file executable as instructed above, the only thing remaining is program execution.

<br>

Run the following command inside cosmossnapman directory:

```bash
    ./snapmaker.sh
```

<br>

**Using Crontab**

If you want to execute the script in specified intervals, the most common way to do it, is using Crontab.

Run the following command to edit your crontab file:

```bash
    crontab -e
```

Then add the following at the end of the file for run the SNAPMaker once per day at 10am:

```plaintext
    0 10 * * * /bin/bash /path/to/script/snapmaker.sh > /dev/null 2>&1
```

Then press CTRL+X, answer yes, and press ENTER to save.

<br>

---

<br>


## KNOWN Issues & Bugs:

<br>

There are no known issues at the moment...

---

<br>

## <p align="center" > About the Author </p>

<br>

- Organization: NexuSecurus
- Author: prenats
- Contact: renato@nexusecurus.com
- Year: 2024


 <br>

---


<br>

## <p align="center" > Contribute To Our Effort </p>

<br>

<br>
<table align="center">
  <tr>
    <th>Asset</th>
    <th>Address</th>
  </tr>
  <tr>
    <td>CosmosHub</td>
    <td>cosmos1ravucs2erl88yn07eyudkhzekswcyw8mhy5lpc</td>
  </tr>
  <tr>
    <td>Osmosis</td>
    <td>osmo1ravucs2erl88yn07eyudkhzekswcyw8mll80h2</td>
  </tr>
  <tr>
    <td>AKASH</td>
    <td>akash1ravucs2erl88yn07eyudkhzekswcyw8m6leccz</td>
  </tr>
  <tr>
    <td>Source Protocol</td>
    <td>source1ravucs2erl88yn07eyudkhzekswcyw8m3hdp3x</td>
  </tr>
  <tr>
    <td>Teritori</td>
    <td>tori1ravucs2erl88yn07eyudkhzekswcyw8m4srk6g</td>
  </tr>
</table>

<br>
<br>


<div style="text-align:center">
    <img src="images/ibc.png" alt="Cosmos Ecosystem">
</div>

