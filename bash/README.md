# About spki_openssl.sh

Bash shell script which parses X.509 files (private key, signing request, signed public key) for file and subjectPublicKeyInfo thumbprints.  For some discussion on why these are different, why it matters, see the discussion in the project [README](../README.md).  For some of the proof-of-concept and research, see the Jupyter Notebooks about [openssl](../notebook/openssl.ipynb) and [badssl](../notebook/badssl.ipynb).

# Usage

```shell
$ spki_openssl.sh --help

   Script: spki_openssl.sh (v0.0.5)
Timestamp: 2024-09-13 09:49:46 EDT

Usage: spki_openssl.sh (options)

Description:
    A proof-of-concept script that uses OpenSSL to generate message digests
    (thumbprints) for X.509 certificate files (e.g., private keys, signing
    requests, signed public keys). The script also provides thumbprints
    representing the subjectPublicKeyInfo (SPKI) data corresponding to the file.

Options:
  Required (choose one):
    --private-key <file>        Path to a private key file.
    --signing-request <file>    Path to a signing request file.
    --signed-public-key <file>  Path to a signed public key file.

  Optional:
    --working-folder <folder>   Path to the working folder.
    --digest-algorithm <name>   Digest algorithm (default: sha256).
                                Use 'openssl dgst -list' for supported options.
    -h, --help                  Display this help message.
```

# Parsing RSA and ECC Key Files

If we have access to all files related to the certificate (private key, signing request, and signed public key), we can pass these into the script for the results.

## RSA Files

```shell
$ spki_openssl.sh \
--private-key rsa_private-key.der \
--signing-request rsa_signing-request.der \
--signed-public-key rsa_self-signed-public-key.der

   Script: spki_openssl.sh (v0.0.5)
Timestamp: 2024-09-13 09:50:41 EDT

Checking Dependencies:
  openssl... success (OpenSSL 3.3.1 4 Jun 2024 (Library: OpenSSL 3.3.1 4 Jun 2024))

Private Key Digests:
        File Path: rsa_private-key.der
        File Type: data
  File Thumbprint: (SHA256) 1b:3a:07:6b:9e:95:c1:62:27:86:17:f1:f0:a4:79:a3:58:67:69:a1:d6:08:71:21:45:09:b5:2d:4a:b7:80:49
  SPKI Thumbprint: (SHA256) 33:24:ca:fd:06:53:0f:e1:02:14:9b:48:e2:8f:c7:db:f6:2a:02:3d:a6:95:68:c2:55:9a:e8:ba:67:a5:fb:4b

Signing Request Digests:
        File Path: rsa_signing-request.der
        File Type: DER Encoded Certificate request
  File Thumbprint: (SHA256) 17:b0:c0:a9:a1:38:2a:6e:45:4c:9d:fb:2b:4d:1a:b9:1b:a6:2a:48:46:c4:cb:8b:d5:d4:29:ac:bb:31:ff:cc
  SPKI Thumbprint: (SHA256) 33:24:ca:fd:06:53:0f:e1:02:14:9b:48:e2:8f:c7:db:f6:2a:02:3d:a6:95:68:c2:55:9a:e8:ba:67:a5:fb:4b

Signed Public Key Digests:
        File Path: rsa_self-signed-public-key.der
        File Type: Certificate, Version=3
  File Thumbprint: (SHA256) 38:24:60:2b:58:99:d1:d1:2a:c0:fa:7d:1f:5b:e7:9b:71:bf:c9:04:a8:f5:07:ad:4a:92:7e:7d:45:54:2d:fe
  SPKI Thumbprint: (SHA256) 33:24:ca:fd:06:53:0f:e1:02:14:9b:48:e2:8f:c7:db:f6:2a:02:3d:a6:95:68:c2:55:9a:e8:ba:67:a5:fb:4b
```

## EC files
You can also elect to only focus on a single file.  Below is an example of only focusing on a public key and we chose to use the SHA-1 algorithm.

```shell
$ spki_openssl.sh \
--private-key ec_private-key.der \
--signing-request ec_signing-request.der \
--signed-public-key ec_self-signed-public-key.der

   Script: spki_openssl.sh (v0.0.5)
Timestamp: 2024-09-13 09:50:51 EDT

Checking Dependencies:
  openssl... success (OpenSSL 3.3.1 4 Jun 2024 (Library: OpenSSL 3.3.1 4 Jun 2024))

Private Key Digests:
        File Path: ec_private-key.der
        File Type: data
  File Thumbprint: (SHA256) 16:c6:40:bb:cb:0b:4b:43:45:e9:7b:1d:95:82:dc:a1:a2:46:c4:a8:fc:47:22:8a:d0:e4:81:d2:83:51:8e:c3
  SPKI Thumbprint: (SHA256) 04:35:1c:96:ef:26:b6:cf:6b:b4:b7:89:72:17:53:b7:9e:b9:09:60:e2:d3:2d:94:a8:fb:95:b0:b7:18:81:07

Signing Request Digests:
        File Path: ec_signing-request.der
        File Type: DER Encoded Certificate request
  File Thumbprint: (SHA256) 49:1b:d1:d4:fa:e5:89:7d:ea:32:9b:b2:16:26:df:0f:10:a2:7a:2b:5b:c4:57:1e:00:90:12:36:40:23:c8:e1
  SPKI Thumbprint: (SHA256) 04:35:1c:96:ef:26:b6:cf:6b:b4:b7:89:72:17:53:b7:9e:b9:09:60:e2:d3:2d:94:a8:fb:95:b0:b7:18:81:07

Signed Public Key Digests:
        File Path: ec_self-signed-public-key.der
        File Type: Certificate, Version=3
  File Thumbprint: (SHA256) 56:46:3c:83:9a:86:df:2b:55:52:70:0a:27:c9:eb:44:4f:6a:57:38:b1:10:e7:fd:cd:67:01:a4:e0:e4:cd:a9
  SPKI Thumbprint: (SHA256) 04:35:1c:96:ef:26:b6:cf:6b:b4:b7:89:72:17:53:b7:9e:b9:09:60:e2:d3:2d:94:a8:fb:95:b0:b7:18:81:07
```

## Specific Digest Algorithm

The `--digest-algorithm` option accepts any valid algorithm supported by your OpenSSL deployment.

```shell
$ openssl version
OpenSSL 3.3.1 4 Jun 2024 (Library: OpenSSL 3.3.1 4 Jun 2024)

$ openssl dgst -list
Supported digests:
-blake2b512                -blake2s256                -md4
-md5                       -md5-sha1                  -mdc2
-ripemd                    -ripemd160                 -rmd160
-sha1                      -sha224                    -sha256
-sha3-224                  -sha3-256                  -sha3-384
-sha3-512                  -sha384                    -sha512
-sha512-224                -sha512-256                -shake128
-shake256                  -sm3                       -ssl3-md5
-ssl3-sha1                 -whirlpool
```

Below we invoke the script and specify `sha384` as the digest algorithm.

```shell
$ spki_openssl.sh \
--private-key rsa_private-key.der \
--signing-request rsa_signing-request.der \
--signed-public-key rsa_self-signed-public-key.der \
--digest-algorithm sha384

   Script: spki_openssl.sh (v0.0.5)
Timestamp: 2024-09-13 09:52:52 EDT

Checking Dependencies:
  openssl... success (OpenSSL 3.3.1 4 Jun 2024 (Library: OpenSSL 3.3.1 4 Jun 2024))

Private Key Digests:
        File Path: rsa_private-key.der
        File Type: data
  File Thumbprint: (SHA384) 90:e1:53:27:26:a5:54:cd:c7:b4:c9:4b:54:35:d8:b5:8e:a0:0e:24:ff:4b:47:e9:75:1a:8f:2e:17:19:d9:bd:2a:90:1d:cd:09:fb:46:fe:3d:a7:df:3c:be:ce:31:c9
  SPKI Thumbprint: (SHA384) c5:00:74:38:40:ea:88:f8:32:7c:6f:af:f9:2d:38:18:01:3c:2a:4b:8d:1d:91:26:c2:79:a6:c5:23:a8:ed:94:bd:34:e0:1f:d9:13:39:6b:41:ed:a5:9c:7b:00:77:1b

Signing Request Digests:
        File Path: rsa_signing-request.der
        File Type: DER Encoded Certificate request
  File Thumbprint: (SHA384) 94:d2:17:03:00:78:14:84:3e:be:dc:d1:35:86:17:85:ea:80:06:f0:9a:62:c3:d3:b4:eb:fa:e9:56:c2:d6:a5:03:36:8c:a3:4a:77:e3:4f:9d:4c:8b:cc:c2:a4:0d:56
  SPKI Thumbprint: (SHA384) c5:00:74:38:40:ea:88:f8:32:7c:6f:af:f9:2d:38:18:01:3c:2a:4b:8d:1d:91:26:c2:79:a6:c5:23:a8:ed:94:bd:34:e0:1f:d9:13:39:6b:41:ed:a5:9c:7b:00:77:1b

Signed Public Key Digests:
        File Path: rsa_self-signed-public-key.der
        File Type: Certificate, Version=3
  File Thumbprint: (SHA384) a5:74:d7:34:89:07:2a:68:db:44:d6:68:fe:27:8d:5f:6a:66:8c:d1:be:34:b6:b6:c1:2e:2c:4c:82:8e:b6:81:de:a5:ae:1c:72:8c:c9:db:2d:b4:f7:aa:b7:51:6d:d8
  SPKI Thumbprint: (SHA384) c5:00:74:38:40:ea:88:f8:32:7c:6f:af:f9:2d:38:18:01:3c:2a:4b:8d:1d:91:26:c2:79:a6:c5:23:a8:ed:94:bd:34:e0:1f:d9:13:39:6b:41:ed:a5:9c:7b:00:77:1b
```

You can also mix and match the different files and algorithms.  Below we compute the `sha1` (eww) against the private key only.

```shell
$ spki_openssl.sh \
--private-key rsa_private-key.der \
--digest-algorithm sha1

   Script: spki_openssl.sh (v0.0.5)
Timestamp: 2024-09-13 09:55:42 EDT

Checking Dependencies:
  openssl... success (OpenSSL 3.3.1 4 Jun 2024 (Library: OpenSSL 3.3.1 4 Jun 2024))

Private Key Digests:
        File Path: rsa_private-key.der
        File Type: data
  File Thumbprint: (SHA1) 8c:93:03:61:74:f3:3e:0a:e8:22:e3:43:87:54:a4:5c:17:44:26:21
  SPKI Thumbprint: (SHA1) bd:41:7d:c6:4a:19:b7:3d:19:9d:d6:ef:64:1c:c2:bc:0c:c4:6b:b2
``` 

# Useful Commands

## Symbolic Links

It can be useful to create symbolic links to select keys and files for use with the bash shell script.  Rather than go through a whole other process of creating RSA and EC keys and certificates, just symlink the sample set.  By doing so you can see the same digests between the Jupyter Notebook and the bash shell script.

> Note: these commands create a symbolic link to files generated from the Jupyter Notebook, see [openssl.ipynb](../notebook/openssl.ipynb) and run through RSA and EC proof-of-concept cells.

```shell
cd ~Development/Home/spki_openssl/tests/grrcon

# define the folder of origin for all sample certificates
FOLDER=~/Development/Home/spki_openssl/notebook/data/poc
# or..
FOLDER=../../notebook/data/poc/

# symlink private keys
ln -sf ${FOLDER}/rsa_private-key.der rsa_private-key.der
ln -sf ${FOLDER}/ec_private-key.der ec_private-key.der

# symlink signing requests
ln -sf $(ls ${FOLDER}/rsa_signing-request*.der | sort | head -n 1) rsa_signing-request.der
ln -sf $(ls ${FOLDER}/ec_signing-request*.der | sort | head -n 1) ec_signing-request.der

# symlink signed public keys
ln -sf $(ls ${FOLDER}/rsa_self-signed-public-key*.der | sort | head -n 1) rsa_self-signed-public-key.der
ln -sf $(ls ${FOLDER}/ec_self-signed-public-key*.der | sort | head -n 1) ec_self-signed-public-key.der

```

```shell
cd ~Development/Home/spki_openssl/tests/grrcon

spki_openssl.sh \
--private-key rsa_private-key.der \
--signing-request rsa_signing-request.der \
--signed-public-key rsa_self-signed-public-key.der

spki_openssl.sh \
--private-key ec_private-key.der \
--signing-request ec_signing-request.der \
--signed-public-key ec_self-signed-public-key.der
```