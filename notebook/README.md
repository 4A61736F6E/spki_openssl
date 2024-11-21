# Jupyter Notebook Setup

These instructions are intended to support how the development environment was setup to support use of the Jupyter Notebook.  The goal is to offer an interactive document (see [openssl.ipynb](./openssl.ipynb)).  These instructions were setup using MacOS.

# macOS Setup

Resources I found useful for setting up the virtual environment.
* [Introduction to `pyenv` (Real Python)](https://realpython.com/intro-to-pyenv/)

My crude shell commands for setup.
```shell

# setup Python
pyenv install 3.12

# create the virtual environment, name can be whatever you want
pyenv virtualenv 3.12 spki-o

# assign the virtual environment to the project
pyenv local spki-o

# install dependencies
poetry install

# add 'notebook' to the production or development group
poetry add notebook --group dev 

# update poetry as needed
poetry update
```

# Kali Linux


## Update and Upgrade the Operating System
Update the operating system and then upgrade to the latest available.

```shell
sudo apt update

sudo apt upgrade -y
```

## Optional: Setup SSH Service
Just makes it easier to copy and paste commands from documentation to environment.

```shell

sudo systemctl enable ssh

sudo systemctl start ssh

```

## Install `pyenv` for Python Virtual Environments
The following instructions adapted from the Medium article [Easy-to-Follow Guide of How to Install PyENV on Ubuntu](https://medium.com/@aashari/easy-to-follow-guide-of-how-to-install-pyenv-on-ubuntu-a3730af8d7f0)

```shell
# Step 2 (Optional): Install Required Dependencies
sudo apt install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

# Step 3: Installing PyENV
curl https://pyenv.run | bash

#Step 4: Setting Up Environment Variables
# modify the zsh rc file . . . 
vi ~/.zshrc

# . . with the following contents
# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

eval "$(pyenv virtualenv-init -)"

# Step 5: Refresh Your Shell
exec "$SHELL"

# Step 6: Confirming PyENV Installation
pyenv --version
# pyenv 2.4.19
```

## Install Python Poetry
Install Python `poetry` for Python dependency management.

```shell
sudo apt install python3-poetry -y

poetry --version
# Poetry (version 1.8.3)
```


## Clone the `spki_openssl` repository

```shell
git clone git@github.com:4A61736F6E/spki_openssl.git

cd spki_openssl

# can take a while
pyenv install 3.12

pyenv virtualenv 3.12 spki-o

pyenv local spki-o

poetry install

```

## Setup Juypter Notebooks on Kali

Instructions derived from [How to Install Jupyter Notebook on Linux](https://www.geeksforgeeks.org/how-to-install-jupyter-notebook-in-linux/).  You also need the Linux tool `uuidgen`, the apt install for this package on Kali Linux is shown.

```shell
sudo apt install jupyterlab -y

sudo apt install uuid-runtime -y

curl -v http://localhost:8888

* Host localhost:8888 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:8888...
* Connected to localhost (::1) port 8888
* using HTTP/1.x
> GET / HTTP/1.1
> Host: localhost:8888
> User-Agent: curl/8.11.0
> Accept: */*
>
* Request completely sent off
< HTTP/1.1 302 Found
< Server: TornadoServer/6.4.1
< Content-Type: text/html; charset=UTF-8
< Date: Thu, 21 Nov 2024 20:52:50 GMT
< Location: /lab?
< Content-Length: 0
<
* Connection #0 to host localhost left intact
```

## Jupyter Server

From the project folder, you can invoke the Jupyter server to reference our custom notebooks.  In the following example, the `spki-openssl` project was cloned and saved to `~/Development/spki-openssl`.  The path where you stored the project may be different.

```shell
cd ~/Development/spki-openssl

ls -l -gG notebook
# total 316
# -rw-rw-r-- 1 146319 Nov 21 15:31 badssl.ipynb
# drwxrwxr-x 3   4096 Nov 21 16:07 data
# -rw-rw-r-- 1 167635 Nov 21 16:16 openssl.ipynb
# -rw-rw-r-- 1    821 Nov 21 15:31 README.md

jupyter-lab --notebook-dir=`pwd`/notebook
```

The `--notebook-dir` sets the scope for where the Jupyter Lab server should consider the working folder.  

You should receive in the output a custom url for `http://localhost:8888/lab?token=02646...`.  Copy and paste this link into Firefox of the Kali Linux desktop environment.  From there, you should be able to interact with the notebook accordingly.



