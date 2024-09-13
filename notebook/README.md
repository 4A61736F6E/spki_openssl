# Jupyter Notebook Setup

These instructions are intended to support how the development environment was setup to support use of the Jupyter Notebook.  The goal is to offer an interactive document (see [openssl.ipynb](./openssl.ipynb)).  These instructions were setup using MacOS.


Resources I found useful for setting up the virtual environment.
* [Introduction to `pyenv` (Real Python)](https://realpython.com/intro-to-pyenv/)


My crude shell commands for setup.
```shell

# setup Python
$ pyenv install 3.12

# create the virtual environment, name can be whatever you want
$ pyenv virtualenv 3.12 spki-o

# assign the virtual environment to the project
$ pyenv local spki-o

# initialized poetry
$ poetry init

# add 'notebook' to the production or development group

# update poetry as needed
$ poetry update
```


