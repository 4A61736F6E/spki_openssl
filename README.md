# spki_openssl

Proof-of-concept shell code and Jupyter Notebook supporting X.509 SubjectPublicKeyInfo research.

This work is divided into a couple areas of interest.  First, there is an interactive Jupyter Notebook based on Python, bash, and OpenSSL.  This was an instrumental tool when learning about the differences between certificate thumbprints and the thumbprint of the subjectPublicKeyInfo (or SPKI) field.  See the [notebook](./notebook) folder where there exists a light [notebook readme](./notebook/README.md) for instructions on the Python configuration.

Second, a stand-alone shell script (bash) was created derived from the Notebook research.  This is just a simple tool to help illustrate the differences between certificate and SPKI thumbprints. See the [bash](./bash) folder and [readme](./bash/README.md) for more information.

Finally, the following research attempts to walk the reader through identifying the `openssl` parameters and arguments necessary to answer our questions.  It is a bit verbose in the writing but hopefully the detail will help increase understanding of the reader.

# Research

Certificate management, for most, is an arcane art, even within the Information Security community.  Some time ago I asked a few key questions and then sought to answer those questions in my own research.  Initially I only had a couple questions that came to mind.  However, as the study grew, more questions emerged, as summarized below.

1. As an Apache administrator, there are many files associated with years of certificate renewal. How do you correlate related _private key_, _signing request_, and _signed public key_ files?
2. To meet compliance requirements, what proof data can we share that demonstrates X.509 cryptographic key rotation or replacement?
3. As an incident handler, in the event of X.509 private key compromise, what inventory can we use to understand the true scope of key replacement? 
4. Finally, how can we make this process agnostic to key types, supporting not just RSA keys but EC keys.

This work is an attempt to expand our understanding of the X.509 certificate fields to answer these questions.  

## Background

If you search how to correlate certificate file types, a common response is to use `openssl` and compare the digest from the `modulus` field as exampled below.  

```shell
# What is the raw output of the command?
$ openssl rsa -noout -modulus -in rsa_private_key.der
Modulus=D2743416B1F128F98FFFCA747A476A2BF4BD56173A4B62016180BBC436685A4967795EB54C9A496B7E057F0728E5F6FCA85A17A7BDD79C801C013EB19643D0FE4897322987522576E97F9C2206AB3F2C8646A9C79D1EAEA64A6CC06552F90CAE3E135A5B1393F78427888FA03C7CE4AA21E980A956F14C3213CB8950D987FDA1614602746E6875890D492B707CD659387024902B434BF6578ECE089648DA31B829E8FAADCEF12273F44A2CD7E7260FD2A691DAA5B4BEE799950B1255AEAA0ABD29789D56840A2389D294CAF78E5AE988EF368CF53DF67EB1DE20795AF87D11590A376834E5AB900B59D26B65E313E4A08C118FDAFE05BCAB89F72F5CAC3A3099

# Display the digest of the private key RSA modulus.
$ openssl rsa -noout -modulus -in rsa_private_key.der | openssl sha256
SHA2-256(stdin)= 87a029b932a258fc3300c077322ccff54bae47a0b80a8a1a4c68cbfb9084656e

# Display the digest of the signing request RSA modulus.
$ openssl req -noout -modulus -in rsa_signing_request.der | openssl sha256
SHA2-256(stdin)= 87a029b932a258fc3300c077322ccff54bae47a0b80a8a1a4c68cbfb9084656e

# Display the digest of the signed certificate RSA modulus.
$ openssl x509 -noout -modulus -in rsa_self-signed_public_key.der | openssl sha256
SHA2-256(stdin)= 87a029b932a258fc3300c077322ccff54bae47a0b80a8a1a4c68cbfb9084656e
```

While this does work for the first question, it is not well-suited to support the remaining questions.  For example, using the same commands against a set of EC certificate files, we receive errors from `openssl`.  The reason these comamnds fail is because RSA and EC key types have different fields and structures.  As an example, EC keys do not have the RSA key _modulus_ or _exponent_ fields.  Instead, there is the _parameters_ field which defines which curve type the key is based. 

```shell
# We fail two different ways attempting to access the modulus field in an
# EC key type as elliptic keys do not contain modulus fields.
$ openssl rsa -noout -modulus -in ec_private_key.der
Not an RSA key

$ openssl ec -noout -modulus -in ec_private_key.der
ec: Unknown option or cipher: modulus
ec: Use -help for summary.
40CF5FED01000000:error:0308010C:digital envelope routines:inner_evp_generic_fetch:unsupported:crypto/evp/evp_fetch.c:355:Global default library context, Algorithm (modulus : 0), Properties (<null>)

# Failure attempting to proccess signing requests . . . 
$ openssl req -noout -modulus -in ec_signing_request.der
Modulus=Wrong Algorithm type

# And failure also when processing signed certificates.
$ openssl x509 -noout -modulus -in ec_self-signed_public_key.der
Modulus=No modulus for this public key type
```

## Certificate Thumbprints

Throughout this document the terms 'digest', 'thumbprint', 'fingerprint', 'hash' may be reference.  These each are alternate names to the same thing.  Data is passed through a hashing algorithm (e.g. SHA-1, SHA-256) and the resulting output is a message digest or thumbprint.  This thumbprint helps us assert the integrity of the source data fed into the algorithm.

We can check the thumbprint of the certificate saved to disk as either a base64 encoded PEM file or as a binary encoded DER file.  While the certificate contents remain the same, the format of the certificate will provide different digest values.  The differences between a PEM and DER encoded certificates is similar to a whitepaper saved as `.txt`  vs `.rtf` vs `.doc` vs `.pdf` document types.  Each represents the same data, yet, when using different encoding methods

Various tools, when representing a certificate and it's thumbprint, process the certificate file as a whole _in its binary (or DER) form_.  It is not a field contained within the X.509 certificate strucuture.  This is easily misunderstood as tools often group the thumbprint data with contents from the certificate such as the `Subject Name`, `Validity Period`, `Issuer` and more.

### Thumbprints using OpenSSL

Using command line Linux tools, we can study the differences between certificate file types.

```shell
# Download the badssl.com certificate file
WORKING_FOLDER=tests

echo "GET" | \
openssl s_client -connect badssl.com:443 2>/dev/null | \
openssl x509 -inform PEM -outform PEM -out $WORKING_FOLDER/badssl.com.pem 2>/dev/null

# Convert our base64 encoded file (PEM) into a binary encoded file (DER)
openssl x509 -inform PEM -outform DER -in $WORKING_FOLDER/badssl.com.pem -out $WORKING_FOLDER/badssl.com.der

# Check the file type of each
file $WORKING_FOLDER/badssl.com*

# command output
tests/badssl.com.der: Certificate, Version=3
tests/badssl.com.pem: PEM certificate

# Demonstrate both files are the same but just in different encoding schemes (PEM)
openssl x509 -inform PEM -noout -text -in $WORKING_FOLDER/badssl.com.pem | grep -A 1 'Serial Number:'

# command output
        Serial Number:
            03:56:9b:ee:34:cd:e3:27:1a:52:80:d4:28:fc:00:ff:43:9b

# Demonstrate both files are the same but just in different encoding schemes (DER)
openssl x509 -inform DER -noout -text -in $WORKING_FOLDER/badssl.com.der | grep -A 1 'Serial Number:'

# command output
        Serial Number:
            03:56:9b:ee:34:cd:e3:27:1a:52:80:d4:28:fc:00:ff:43:9b

# The digests of each file is unique and different even though they represent the same content.
sha256sum $WORKING_FOLDER/badssl.com*

# command output
faa1631b647c2d3a3367f7fa45b89d0da256f0f29f9f8dd33039d55ead29d627  tests/badssl.com.der
bfa49f7c777245db50a98a108e2e8698887ec85b2fb7afecf736023beacf4aa4  tests/badssl.com.pem

sha1sum $WORKING_FOLDER/badssl.com*

# command output
0e9ca203f0af6caeb121174c2c89e25a409a3c9f  tests/badssl.com.der
71cfacceb1aae8e61f3a82bd6f40709fae82ea1a  tests/badssl.com.pem
```

When we preview the certificate using a web browser or operating system, these tools will compute the thumbprint (e.g. SHA-1, SHA-256) of the binary representation of the file (DER), not the base64 representation (PEM).  Windows or macOS or Linux operating systems may present the data in slightly different formats (upper cases, lower case, colon delimited, etc) just as Chromium, Firefox, or Safari browsers may offer unique presentation experiences.  While there may be slight variations of the presentation, the charcter sets will be the same.  The following images show the SHA-1 digest of the certificate between macOS and Windows systems.

| macOS Quick Look | Windows Certificate View |
|------------------|--------------------------|
| <img src=./images/macOS_certificate_quick_look.png width=75% height=7%> | <img src=./images/Windows_certificate_quick_look.png width=65% height=65%> |

Regardless of the tool used to view the certificate, each will show a thumbprint using one of the common algorithms such as SHA-1 or SHA-256.  Again, the certificate thumbprint is derived from the binary form of the certificate passed through one of the hashing functions.

### Thumbprints using Wireshark

You can also export the certificate in binary form using Wireshark.  Here I used a capture filter to narrow my Wireshark packets to the web site in question.  Next, I used a display filter to look specifically for the TLS handshake (e.g. `ip.addr == 104.154.89.105 && ssl.handshake.certificate`).  In the Wireshark interface, navigate to the first certificate in the chain sent in the handshake.  From there we can export this certificate in binary (or raw) format.

<img src=./images/wireshark_cert_export.png  width=40% height=40%>

In this example, I saved the file to `tests/badssl.com.bin`.  With the binary export complete, we can compare the previous `.der` and our new `.bin` files to show they are the same.  

```shell
# using Linux utility, sha256sum
sha256sum tests/badssl.com.bin tests/badssl.com.der

# command output
faa1631b647c2d3a3367f7fa45b89d0da256f0f29f9f8dd33039d55ead29d627  tests/badssl.com.bin
faa1631b647c2d3a3367f7fa45b89d0da256f0f29f9f8dd33039d55ead29d627  tests/badssl.com.der

# using openssl command options
openssl dgst -sha256 tests/badssl.com.bin tests/badssl.com.der

# command output
SHA2-256(tests/badssl.com.bin)= faa1631b647c2d3a3367f7fa45b89d0da256f0f29f9f8dd33039d55ead29d627
SHA2-256(tests/badssl.com.der)= faa1631b647c2d3a3367f7fa45b89d0da256f0f29f9f8dd33039d55ead29d627
```

## RFC References

Exploring [RFC 5280, Section 4.1](https://datatracker.ietf.org/doc/html/rfc5280#section-4.1) we are shown the following structure for the X.509 certificate.  The point of interest is in the `SubjectPublicKeyInfo` field which contains the key type, key parameters, and the public key material used for encryption or decryption operations.

```text
Certificate  ::=  SEQUENCE  {
    tbsCertificate       TBSCertificate,
    signatureAlgorithm   AlgorithmIdentifier,
    signatureValue       BIT STRING  }

TBSCertificate  ::=  SEQUENCE  {
    version         [0]  EXPLICIT Version DEFAULT v1,
    serialNumber         CertificateSerialNumber,
    signature            AlgorithmIdentifier,
    issuer               Name,
    validity             Validity,
    subject              Name,
    subjectPublicKeyInfo SubjectPublicKeyInfo,
    issuerUniqueID  [1]  IMPLICIT UniqueIdentifier OPTIONAL,
                        -- If present, version MUST be v2 or v3
    subjectUniqueID [2]  IMPLICIT UniqueIdentifier OPTIONAL,
                        -- If present, version MUST be v2 or v3
    extensions      [3]  EXPLICIT Extensions OPTIONAL
                        -- If present, version MUST be v3 }

SubjectPublicKeyInfo  ::=  SEQUENCE  {
    algorithm            AlgorithmIdentifier,
    subjectPublicKey     BIT STRING  }

```

We can see RSA and Elliptic Curve key types have varying structures.  Reviewing certifiates from the `badssl.com` web site (as of September '24) we can study the ASN.1 structure using an ASN.1 JavaScript Decoder [https://lapo.it/asn1js/](https://lapo.it/asn1js/).  Below are two certificates from specific websites for reference.  

See [rsa2048.badssl.com ASN.1 JavaScript Decoder](https://lapo.it/asn1js/#MIIE9TCCA92gAwIBAgISA1ab7jTN4ycaUoDUKPwA_0ObMA0GCSqGSIb3DQEBCwUAMDMxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQwwCgYDVQQDEwNSMTEwHhcNMjQwODA5MTUwNTQ0WhcNMjQxMTA3MTUwNTQzWjAXMRUwEwYDVQQDDAwqLmJhZHNzbC5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCdKl6MexmrIYkfRqx7vdbFaZbnR3XrZSSavFBpbAJEai04zUz4Zz40XB_-GhAHxvPisjBBoMTeIM4sxIhXy1gqbL2WckFpvBOBNII-smLJoonUM9LA8i14fv8jqQTjHQyeZtDdlM_PRh-orS1Wwg8L3507sDGH7Ex6QEmUiHGTXluqCDUjyGcuQyuc5xZUNdJmUZKnVWMbja6RLnecueTBlGfzwZMU_hFXtcZMCuE-FFCwyVYacFfNhMm3ckV5hwFchFBfo3lQzJ8hYLTKMABjXyR-WTPxjriZRYFWOYRcQI15Bo8taAYDh6lXcj5A71QFtrlIxPAm57yaVs54c8VdAgMBAAGjggIdMIICGTAOBgNVHQ8BAf8EBAMCBaAwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB_wQCMAAwHQYDVR0OBBYEFA17gxGErjYsooUaK-vPPbg1gnv8MB8GA1UdIwQYMBaAFMXPRqTq9MPAemyVxC2wXpIvJuO5MFcGCCsGAQUFBwEBBEswSTAiBggrBgEFBQcwAYYWaHR0cDovL3IxMS5vLmxlbmNyLm9yZzAjBggrBgEFBQcwAoYXaHR0cDovL3IxMS5pLmxlbmNyLm9yZy8wIwYDVR0RBBwwGoIMKi5iYWRzc2wuY29tggpiYWRzc2wuY29tMBMGA1UdIAQMMAowCAYGZ4EMAQIBMIIBBQYKKwYBBAHWeQIEAgSB9gSB8wDxAHYAPxdLT9ciR1iUHWUchL4NEu2QN38fhWrrwb8ohez4ZG4AAAGRN-IpPwAABAMARzBFAiEAlOextQPh6MzDGzxHzPpPdQSZ16fY0aywyCZCc7Jn97QCIFtgQR4Mln3moYmnspFkbYdScPWLFnBQC_DiehhdarEYAHcAdv-IPwq2-5VRwmHM9Ye6NLSkzbsp3GhCCp_mZ0xaOnQAAAGRN-IpkgAABAMASDBGAiEA_l8-xhtC9tWAQ9OszOIfH34qXgQYgPp88fjoqlxurKMCIQC9HK-l_Vv0_51JDd9J71Hh58OmCJ9cV3LbFrlRAgEC6zANBgkqhkiG9w0BAQsFAAOCAQEAZ7Vcj83IL5Vs0wEC7DPR-maB78xyNgnCMIKcySlYxzWU0rNd30jIhnrFlDafM1-yB9Qlp3pI0Dgu5zBPL9BbRh9Y4AQhg0ybgqNH2mY_MWYtm-RtKK-eXsCmdSTxZfhfUsUirdC3EIhMwTFdFOGib-6IOYLuwS-20CRUoG4EvZkt_J_qtxMDorLpVkbESmgUIKtdEbK2-JlL9_RgDRM7TETMy8tKkQtzk56kFf-2MOvHmWS0gi8JSZSaZjYuvxRMqgXWgZu1HX3TCwwg7AfGE0VgTJUw3Sps_NvNVzITt_0zf5WvBLrTN_s9EaN5iVVgKwn1dC0sYoIoY0v_iv4_eg).  The 2048 bits beneath `subjectPublicKeyInfo` > `subjectPublicKey BIT String` references the RSA modulus.  

```text
subjectPublicKeyInfo SubjectPublicKeyInfo SEQUENCE (2 elem)
        algorithm AlgorithmIdentifier SEQUENCE (2 elem)
                algorithm OBJECT IDENTIFIER 1.2.840.113549.1.1.1 rsaEncryption (PKCS #1)
                parameters ANY NULL
        subjectPublicKey BIT STRING (2160 bit)
                SEQUENCE (2 elem)
                        INTEGER (2048 bit) 
                        INTEGER 65537
```

However, when we view the EC key, we notice there is no modulus - different algorithm, different parameters, see[ecc256.badssl.com ASN.1 JavaScript Decoder](https://lapo.it/asn1js/#MIIDhjCCAwygAwIBAgISA9wz-CqbgNiNxRmepHp5hHjCMAoGCCqGSM49BAMDMDIxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQswCQYDVQQDEwJFNTAeFw0yNDA4MDkxNTA1MzZaFw0yNDExMDcxNTA1MzVaMBcxFTATBgNVBAMMDCouYmFkc3NsLmNvbTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABO1pUkMk4gM66h-alQ9_OOsdHyy7vUfON1_pCXbo_W5Qncz0VgSlEdu_EtvsJDTROZ0njIPHPWa7o6s3cTQnnQyjggIbMIICFzAOBgNVHQ8BAf8EBAMCB4AwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB_wQCMAAwHQYDVR0OBBYEFI_9xntgW2zfwTB-hT1nhI0i0LufMB8GA1UdIwQYMBaAFJ8rX888IU-dBLftKyzExnCL0tcNMFUGCCsGAQUFBwEBBEkwRzAhBggrBgEFBQcwAYYVaHR0cDovL2U1Lm8ubGVuY3Iub3JnMCIGCCsGAQUFBzAChhZodHRwOi8vZTUuaS5sZW5jci5vcmcvMCMGA1UdEQQcMBqCDCouYmFkc3NsLmNvbYIKYmFkc3NsLmNvbTATBgNVHSAEDDAKMAgGBmeBDAECATCCAQUGCisGAQQB1nkCBAIEgfYEgfMA8QB2AEiw42vapkc0D-VqAvqdMOscUgHLVt0sgdm7v6s52IRzAAABkTfiCaAAAAQDAEcwRQIhANnKy5AniVvEPBFlO9hqHjSkd72IavtXZcHHZ-TBLWdxAiAhy8FWc2ie15Nb2RsszP5uNvxQYxbx743sraNc1pUxWAB3AD8XS0_XIkdYlB1lHIS-DRLtkDd_H4Vq68G_KIXs-GRuAAABkTfiEXgAAAQDAEgwRgIhAPLTI7XUt2QST7rUIcnUbceiZOKxL43j1QqkaaocLRqhAiEA2_1cOCVy2Vo3eKvOg3dMSLEZh3GpY9I2gDbe7YOpak8wCgYIKoZIzj0EAwMDaAAwZQIwKT5oizwg-7F6vi2pb3SMRMyviZiXlpEpX5mizNwxul_-ot98KrqJmigJ-ZxAns_CAjEA-r1qIORrVbXkRBpJGcTIuRtuAFFMqi7jotmeoIxJnt3Pt3t0JyaWp_Q1Vz4cNR0I).

```
subjectPublicKeyInfo SubjectPublicKeyInfo SEQUENCE (2 elem)
        algorithm AlgorithmIdentifier SEQUENCE (2 elem)
                algorithm OBJECT IDENTIFIER 1.2.840.10045.2.1 ecPublicKey (ANSI X9.62 public key type)
                parameters ANY OBJECT IDENTIFIER 1.2.840.10045.3.1.7 prime256v1 (ANSI X9.62 named elliptic curve)
        subjectPublicKey BIT STRING (520 bit) 
```

Whether viewing the certification information in Wireshark or the JavaScript parser, what becomes apparent is the ASN.1 structure of the fields contained within the X.509 file.  If we pivot our emphasis away from specific algorithm fields (e.g. RSA modulus) to the parent of the public key structure, we see there is the `subjectPublicKeyInfo` field.

## SubjectPublicKeyInfo using OpenSSL

Using the `openssl` command we can interface with the various file types to access the public key material.  

| File Type         | Base `openssl` command     |
|-------------------|----------------------------|
| Private Key       | `openssl pkey -pubout ...` |
| Signing Request   | `openssl req -pubkey ...`  |
| Signed Public Key | `openssl x509 -pubkey ...` | 


The following analysis sections depend on the following files.  

| File Name | Description |
|-----------|-------------|
| rsa_private-key.der | RSA private key in binary form. |
| rsa_private-key.pem | RSA private key in ASCII text form. |
| rsa_signing-request.pem | RSA signing request in ASCII text form. |
| rsa_self-signed-public-key.der | RSA self-signed public key in binary form. |
| rsa_self-signed-public-key.pem | RSA self-signed public key in ASCII text form. |
| | |
| ec_private-key.der | EC private key in binary form. |
| ec_private-key.pem | EC private key in ASCII text form. |
| ec_signing-request.pem | EC signing request in ASCII text form. |
| ec_self-signed-public-key.der | EC self-signed public key in binary form. |
| ec_self-signed-public-key.pem | EC self-signed public key in ASCII text form. |

Borrowing from the [OpenSSL Jupyter Notebook](./notebook/openssl.ipynb), we can use the following shell code copy files to a working folder for analysises apart from the notebook.  This assumes you have not reset the notebook sample data and have completed at least one full execution of the RSA and EC notebook sections.  

```shell
# Set source and working folders
SOURCE_FOLDER=notebook/data/poc
WORKING_FOLDER=tests/demo

mkdir -p ${WORKING_FOLDER}

# copy private keys
cp $SOURCE_FOLDER/rsa_private-key.der $WORKING_FOLDER/
cp $SOURCE_FOLDER/rsa_private-key.pem $WORKING_FOLDER/
cp $SOURCE_FOLDER/ec_private-key.der $WORKING_FOLDER/
cp $SOURCE_FOLDER/ec_private-key.pem $WORKING_FOLDER/

# copy signing requests
cp $(ls $SOURCE_FOLDER/rsa_signing-request*.der | sort | head -n 1) \
$WORKING_FOLDER/rsa_signing-request.der
cp $(ls $SOURCE_FOLDER/rsa_signing-request*.pem | sort | head -n 1) \
$WORKING_FOLDER/rsa_signing-request.pem
cp $(ls $SOURCE_FOLDER/ec_signing-request*.der | sort | head -n 1) \
$WORKING_FOLDER/ec_signing-request.der
cp $(ls $SOURCE_FOLDER/ec_signing-request*.pem | sort | head -n 1) \
$WORKING_FOLDER/ec_signing-request.pem

# copy signed public keys
cp $(ls $SOURCE_FOLDER/rsa_self-signed-public-key*.der | sort | head -n 1) \
$WORKING_FOLDER/rsa_self-signed-public-key.der
cp $(ls $SOURCE_FOLDER/rsa_self-signed-public-key*.pem | sort | head -n 1) \
$WORKING_FOLDER/rsa_self-signed-public-key.pem
cp $(ls $SOURCE_FOLDER/ec_self-signed-public-key*.der | sort | head -n 1) \
$WORKING_FOLDER/ec_self-signed-public-key.der
cp $(ls $SOURCE_FOLDER/ec_self-signed-public-key*.pem | sort | head -n 1) \
$WORKING_FOLDER/ec_self-signed-public-key.pem
```

### RSA Key Analysis

In the below samples, we compare the thumbprints of public key material extracted from RSA _private key_, _signing request_, and _public key_ files.  

```shell
WORKING_FOLDER=tests/demo

# RSA Private Key
openssl pkey -pubout -inform DER -outform DER -in $WORKING_FOLDER/rsa_private-key.der | \
openssl dgst -sha256 -c

# command output
SHA2-256(stdin)= ab:a9:c4:31:a6:48:c0:0b:bc:69:fa:0d:f9:39:4b:b7:01:e9:77:14:13:f1:d0:e8:68:66:c2:9d:c4:ea:c7:2d
```

- `openssl pkey` specifies we wish to work with private and public keys.
- `-pubout` indicates we are only interested in the public key material corresponding to the private key.
- `-inform` specifies our read encoding scheme (PEM or DER)
- `-outform` specifies our output encoding scheme (PEM or DER)
- `-in` defines the file we wish to read


```shell
WORKING_FOLDER=tests/demo

# RSA Signing Request
openssl req -pubkey -inform PEM -outform PEM -in $WORKING_FOLDER/rsa_signing-request.pem | \
sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | \
openssl asn1parse -noout -inform PEM -out /dev/stdout | \
openssl dgst -sha256 -c

# command output
SHA2-256(stdin)= ab:a9:c4:31:a6:48:c0:0b:bc:69:fa:0d:f9:39:4b:b7:01:e9:77:14:13:f1:d0:e8:68:66:c2:9d:c4:ea:c7:2d
```

- `openssl req` indicates we wish to work with certificate signing request files.
- `-pubkey` specifies we wish to export the public key material only, ignoring all other contextual components.
- `-inform`, `-outform` specify expected encoding schemes

By default `openssl req -pubkey...` output includes more information than we need (below) so we use `sed` to extract only the `PUBLIC KEY` information.

```text
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE3sevUppF9gZ+OkbUTtn/hTNMXnTr
7XKubdnt7F7XnAqbIXXY5tV48pQz1jkCD/VN2z+VvyEDyvTjXtLRRrsbBg==
-----END PUBLIC KEY-----
-----BEGIN CERTIFICATE REQUEST-----
MIIBFDCBvAIBADBaMSkwJwYDVQQKDCBXQVJOSU5HOiBQUklWQVRFIEtFWSBNQURF
IFBVQkxJQzEtMCsGA1UEAwwkNDYxNTk3MDAtRTkwNS00MDYyLTk5M0YtN0Y1ODE3
NUYwOUFBMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE3sevUppF9gZ+OkbUTtn/
hTNMXnTr7XKubdnt7F7XnAqbIXXY5tV48pQz1jkCD/VN2z+VvyEDyvTjXtLRRrsb
BqAAMAoGCCqGSM49BAMCA0cAMEQCIHmsUJ3Ls5zPkQ+aabmXBdf66An40h3h/CjZ
rl8HqlGNAiBBizanqPgBB5it5lAwch2uUtIv28mSiVMEKCC0C5Mxhw==
-----END CERTIFICATE REQUEST-----
```

Next, we pipe the information to `openssl asn1parse` to convert the ASCII data back into a binary form.  We use standard output (`/dev/stdout`) as the file to write against to avoid a temporary file and allow us to pipe the data to `openssl dgst` command.


```shell
WORKING_FOLDER=tests/demo

# RSA Signed Public Key
openssl x509 -pubkey -inform pem -in $WORKING_FOLDER/rsa_self-signed-public-key.pem | \
sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | \
openssl asn1parse -noout -inform PEM -out /dev/stdout | \
openssl dgst -sha256 -c

# command output
SHA2-256(stdin)= ab:a9:c4:31:a6:48:c0:0b:bc:69:fa:0d:f9:39:4b:b7:01:e9:77:14:13:f1:d0:e8:68:66:c2:9d:c4:ea:c7:2d
```

- `openssl x509` to work with X.509 certificate files
- `-pubkey` to work with only the public key material
- `-inform` specifies the expected input encoding scheme
- `-in` the file to read from

Similar to the previous step, we pipe the PEM data to `sed` where the `PUBLIC KEY` portion is extracted and then fed to `openssl asn1parse` for conversion into binary form where we compute the digest.

```shell
WORKING_FOLDER=tests/demo

# RSA Private Key SubjectPublicKeyInfo Digest (ASCII input, then Binary)
openssl pkey -pubout -inform PEM -outform DER -in $WORKING_FOLDER/rsa_private-key.pem | \
openssl dgst -sha256 -c

# command output
SHA2-256(stdin)= a1:3c:1e:5b:cb:b9:ef:17:0c:9f:fe:34:35:c7:e6:96:13:63:04:8d:c5:c1:7e:86:c0:cc:bd:35:33:30:17:0f

openssl pkey -pubout -inform DER -outform DER -in $WORKING_FOLDER/rsa_private-key.der | \
openssl dgst -sha256 -c

# command output
SHA2-256(stdin)= a1:3c:1e:5b:cb:b9:ef:17:0c:9f:fe:34:35:c7:e6:96:13:63:04:8d:c5:c1:7e:86:c0:cc:bd:35:33:30:17:0f

# RSA Signing Request SubjectPublicKeyInfo Digest
openssl req -pubkey -inform PEM -outform PEM -in $WORKING_FOLDER/rsa_signing-request.pem | \
sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | \
openssl asn1parse -noout -inform PEM -out /dev/stdout | \
openssl dgst -sha256 -c

# command output
SHA2-256(stdin)= a1:3c:1e:5b:cb:b9:ef:17:0c:9f:fe:34:35:c7:e6:96:13:63:04:8d:c5:c1:7e:86:c0:cc:bd:35:33:30:17:0f

# RSA Signed Public Key SubjectPublicKeyInfo Digest
openssl x509 -pubkey -inform PEM -in $WORKING_FOLDER/rsa_self-signed-public-key.pem | \
sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | \
openssl asn1parse -noout -inform PEM -out /dev/stdout | \
openssl dgst -sha256 -c

# command output
SHA2-256(stdin)= a1:3c:1e:5b:cb:b9:ef:17:0c:9f:fe:34:35:c7:e6:96:13:63:04:8d:c5:c1:7e:86:c0:cc:bd:35:33:30:17:0f
```

### EC Key Analysis

The same commands work just as well for Elliptic Curve keys.  Note, we can mix up the expected `-inform` of the file type to yield so long as the `-outform` remains a binary (DER) encoded structure.

```shell
WORKING_FOLDER=tests/demo

# EC Private Key
openssl pkey -pubout -inform PEM -outform DER -in $WORKING_FOLDER/ec_private-key.pem | \
openssl dgst -sha256 -c

# command output
SHA2-256(stdin)= 1d:29:21:88:d7:6d:59:5e:da:2a:8a:3b:dd:d0:5f:ec:5e:19:7f:59:bb:e5:0a:bc:4a:e7:95:47:46:86:2b:37

# EC Signing Request
openssl req -pubkey -inform PEM -outform PEM -in $WORKING_FOLDER/ec_signing-request.pem | \
sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | \
openssl asn1parse -noout -inform PEM -out /dev/stdout | \
openssl dgst -sha256 -c

# command output
SHA2-256(stdin)= 1d:29:21:88:d7:6d:59:5e:da:2a:8a:3b:dd:d0:5f:ec:5e:19:7f:59:bb:e5:0a:bc:4a:e7:95:47:46:86:2b:37

# EC Signed Public Key
openssl x509 -pubkey -inform PEM -in $WORKING_FOLDER/ec_self-signed-public-key.pem | \
sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | \
openssl asn1parse -noout -inform PEM -out /dev/stdout | \
openssl dgst -sha256 -c

# command output
SHA2-256(stdin)= 1d:29:21:88:d7:6d:59:5e:da:2a:8a:3b:dd:d0:5f:ec:5e:19:7f:59:bb:e5:0a:bc:4a:e7:95:47:46:86:2b:37
```

You can also convert a ASCII (PEM) file into a binary encoded (DER) file and compute it's thumbprint on-demand.  Doing so merely defines the certificate thumbprint, not the public key thumbprint.

```shell
WORKING_FOLDER=tests/demo

# Digest of binary file.
openssl dgst -sha256 -c $WORKING_FOLDER/ec_self-signed-public-key.der

# command output
SHA2-256(ec_self-signed-public-key.der)= df:01:63:4a:65:8e:95:bb:17:a2:50:e4:63:35:b2:f4:36:c0:b8:75:22:c6:d4:14:be:cf:05:10:d3:da:00:c2

# On demand binary digest from ASCII source file
openssl x509 -inform PEM -outform DER -out /dev/stdout -in $WORKING_FOLDER/ec_self-signed-public-key.pem | \
 openssl dgst -sha256 -c

# command output
SHA2-256(stdin)= df:01:63:4a:65:8e:95:bb:17:a2:50:e4:63:35:b2:f4:36:c0:b8:75:22:c6:d4:14:be:cf:05:10:d3:da:00:c2

```

## Conclusion

To the original questions we set out to solve the answer is, "Yes".  Across RSA and EC key types, using a combination of specific `openssl` parameters and options, we can derive or access the `SubjectPublicKeyInfo` field.  Once accessed, we can generate a thumbprint from this data structure to uniquely represent the cryptographic public key material separate from the certificate Subject, AlternativeNames, Validity Periods and other contextual data.


This work is unqiue in that it provides a variety of opitons to study the `SubjectPublicKeyInfo` field.  Commercial entities, like [Hardenize](https://www.hardenize.com/) and [Censys](https://censys.com/), in their X.509 certificate inventory, include the SPKI thumbprint along side the certificate thumbprint.  At some point between 2023 and 2024, the Chromium project expanded the thumbprint shown in the site certificate to show both the _certificate thumbprint_ and the _public key thumbprint_.  While we may call them slightly different things, the hope here is that these resources can help raise awareness to what these thumbprints are, where they come from, and why they are distinct from one another yet very much related.

# Resources

1. [Qualys Community, Detecting Key Reuse, Jason Link](https://success.qualys.com/discussions/s/question/0D52L00004TnxV5SAJ/detecting-key-reuse)
2. [Hardenize](https://www.hardenize.com/)
3. [Censys](https://censys.com/)




