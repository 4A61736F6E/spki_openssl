# spki_openssl

Proof-of-concept shell code and Jupyter Notebook supporting X.509 SubjectPublicKeyInfo research.

This work is divided into a couple areas of interest.  First, there is an interactive Jupyter Notebook based on Python, bash, and OpenSSL.  This was an instrumental tool when learning about the differences between certificate thumbprints and subjectPublicKeyInfo (or SPKI).  See the [notebook](./notebook) folder where there exists a light [notebook readme](./notebook/README.md) for instructions on the Python configuration.

Second, a stand-alone shell script (bash) was created derived from the Notebook research.  This is just a simple tool to help illustrate the differences between certificate thumbprints and the SPKI thumbprints. See the [bash](./bash) folder where also exists a [readme](./bash/README.md) on various executions of the script.

# About this Research

Some time ago I asked these questions of myself and then did some searching out there to try and answer the following questions:

1.  How do you correlate the private key, signing request, and signed public key to one another?
2.  How do you validate that X.509 key material has indeed been rotated during the renewal process?
3.  Can this process apply to both RSA and EC key types alike?"_

A common example to the first question was something akin to the following:

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

While this does work for the first question, it falls short with the second and third questions.  To be precise, using the same commands against a set of EC certificate files, we receive errors from OpenSSL.  The reason is RSA and EC keys have different public key structures.  As an example, EC keys do not have the RSA key `modulus` or `exponent` fields.  Instead, they have elliptic curve parameters which RSA keys do not.

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

Certificate thumbprints represent the certificate file as a whole _in its binary form_.  It is not a field contained within the X.509 certificate strucuture.  This is easily misunderstood as our tools often group the thumbprint data with contents from the certificate (e.g. Subject Name, Validity Period).

We can check the thumbprint of the certificate saved to disk as either a base64 encoded PEM file or as a binary encoded DER file.  While the certificate contents remain the same, the format of the certificat will provide different digest values.  The differences between a PEM and DER encoded certificates is similar to a whitepaper saved as `.txt`  vs `.rtf` vs `.doc` vs `.pdf` document types.  Each represents the same data, just encoded in different ways when saved to disk.

### Thumbprints using OpenSSL

Using command line Linux tools, we can study the differences between certificate file types.

```shell
# Download the badssl.com certificate file
$ echo "GET" | \
openssl s_client -connect badssl.com:443 2>/dev/null | \
openssl x509 -inform PEM -outform PEM -out tests/badssl.com.pem 2>/dev/null

# Convert our base64 encoded file (PEM) into a binary encoded file (DER)
$ openssl x509 -inform PEM -outform DER -in tests/badssl.com.pem -out tests/badssl.com.der

# Check the file type of each
$ file tests/badssl.com*
tests/badssl.com.der: Certificate, Version=3
tests/badssl.com.pem: PEM certificate

# Demonstrate both files are the same but just in different encoding schemes.
$ openssl x509 -inform PEM -noout -text -in tests/badssl.com.pem | grep -A 1 'Serial Number:'
        Serial Number:
            03:56:9b:ee:34:cd:e3:27:1a:52:80:d4:28:fc:00:ff:43:9b
$ openssl x509 -inform DER -noout -text -in tests/badssl.com.der | grep -A 1 'Serial Number:'
        Serial Number:
            03:56:9b:ee:34:cd:e3:27:1a:52:80:d4:28:fc:00:ff:43:9b

# The digests of each file is unique and different even though they represent the same content.
$ sha256sum tests/badssl.com*
faa1631b647c2d3a3367f7fa45b89d0da256f0f29f9f8dd33039d55ead29d627  tests/badssl.com.der
bfa49f7c777245db50a98a108e2e8698887ec85b2fb7afecf736023beacf4aa4  tests/badssl.com.pem

$ sha1sum tests/badssl.com*
0e9ca203f0af6caeb121174c2c89e25a409a3c9f  tests/badssl.com.der
71cfacceb1aae8e61f3a82bd6f40709fae82ea1a  tests/badssl.com.pem
```

When we preview the certificate using a web browser or operating system, these tools will compute the thumbprint (e.g. SHA-1, SHA-256) of the binary representation of the file (DER), not the base64 representation (PEM).  Windows or macOS or Linux operating systems may present the data in slightly different formats just as Chromium, Firefox, or Safari browsers may offer unique presentation experiences.  

<img src=./images/macOS_certificate_quick_look.png width=50% height=50%>

Regardless of the tool used to view the certificate, each will show a thumbprint using one of the common algorithms, usually SHA-1 or SHA-256.  The thumbprint is derived from the binary form of the certificate.

### Thumbprints using Wireshark

You can also export the certificate in binary form using Wireshark.  Using Wireshark display filters, you can narrow the scope of your traffic to the specific site (e.g. `ip.addr == 104.154.89.105 && ssl.handshake.certificate`).  You would need to identify the IP of your test web site before applying this filter (e.g. use `dig` or `nslookup`).  We can navigate to the first certificate in the chain sent in the handshake.  From there we can export this certificate in binary (or raw) format.

<img src=./images/wireshark_cert_export.png  width=40% height=40%>

In this example, I saved the file to `tests/badssl.com.bin` next to the other samples.  With the binary export complete, we can compare the previous `.der` and our new `.bin` files to show they are the same.  

```shell
$ sha256sum tests/badssl.com.bin tests/badssl.com.der
faa1631b647c2d3a3367f7fa45b89d0da256f0f29f9f8dd33039d55ead29d627  tests/badssl.com.bin
faa1631b647c2d3a3367f7fa45b89d0da256f0f29f9f8dd33039d55ead29d627  tests/badssl.com.der
```

# RFC References

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

See [rsa2048.badssl.com ASN.1 JavaScript Decoder](https://lapo.it/asn1js/#MIIE9TCCA92gAwIBAgISA1ab7jTN4ycaUoDUKPwA_0ObMA0GCSqGSIb3DQEBCwUAMDMxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQwwCgYDVQQDEwNSMTEwHhcNMjQwODA5MTUwNTQ0WhcNMjQxMTA3MTUwNTQzWjAXMRUwEwYDVQQDDAwqLmJhZHNzbC5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCdKl6MexmrIYkfRqx7vdbFaZbnR3XrZSSavFBpbAJEai04zUz4Zz40XB_-GhAHxvPisjBBoMTeIM4sxIhXy1gqbL2WckFpvBOBNII-smLJoonUM9LA8i14fv8jqQTjHQyeZtDdlM_PRh-orS1Wwg8L3507sDGH7Ex6QEmUiHGTXluqCDUjyGcuQyuc5xZUNdJmUZKnVWMbja6RLnecueTBlGfzwZMU_hFXtcZMCuE-FFCwyVYacFfNhMm3ckV5hwFchFBfo3lQzJ8hYLTKMABjXyR-WTPxjriZRYFWOYRcQI15Bo8taAYDh6lXcj5A71QFtrlIxPAm57yaVs54c8VdAgMBAAGjggIdMIICGTAOBgNVHQ8BAf8EBAMCBaAwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB_wQCMAAwHQYDVR0OBBYEFA17gxGErjYsooUaK-vPPbg1gnv8MB8GA1UdIwQYMBaAFMXPRqTq9MPAemyVxC2wXpIvJuO5MFcGCCsGAQUFBwEBBEswSTAiBggrBgEFBQcwAYYWaHR0cDovL3IxMS5vLmxlbmNyLm9yZzAjBggrBgEFBQcwAoYXaHR0cDovL3IxMS5pLmxlbmNyLm9yZy8wIwYDVR0RBBwwGoIMKi5iYWRzc2wuY29tggpiYWRzc2wuY29tMBMGA1UdIAQMMAowCAYGZ4EMAQIBMIIBBQYKKwYBBAHWeQIEAgSB9gSB8wDxAHYAPxdLT9ciR1iUHWUchL4NEu2QN38fhWrrwb8ohez4ZG4AAAGRN-IpPwAABAMARzBFAiEAlOextQPh6MzDGzxHzPpPdQSZ16fY0aywyCZCc7Jn97QCIFtgQR4Mln3moYmnspFkbYdScPWLFnBQC_DiehhdarEYAHcAdv-IPwq2-5VRwmHM9Ye6NLSkzbsp3GhCCp_mZ0xaOnQAAAGRN-IpkgAABAMASDBGAiEA_l8-xhtC9tWAQ9OszOIfH34qXgQYgPp88fjoqlxurKMCIQC9HK-l_Vv0_51JDd9J71Hh58OmCJ9cV3LbFrlRAgEC6zANBgkqhkiG9w0BAQsFAAOCAQEAZ7Vcj83IL5Vs0wEC7DPR-maB78xyNgnCMIKcySlYxzWU0rNd30jIhnrFlDafM1-yB9Qlp3pI0Dgu5zBPL9BbRh9Y4AQhg0ybgqNH2mY_MWYtm-RtKK-eXsCmdSTxZfhfUsUirdC3EIhMwTFdFOGib-6IOYLuwS-20CRUoG4EvZkt_J_qtxMDorLpVkbESmgUIKtdEbK2-JlL9_RgDRM7TETMy8tKkQtzk56kFf-2MOvHmWS0gi8JSZSaZjYuvxRMqgXWgZu1HX3TCwwg7AfGE0VgTJUw3Sps_NvNVzITt_0zf5WvBLrTN_s9EaN5iVVgKwn1dC0sYoIoY0v_iv4_eg).  The 2048 bits beneath `subjectPublicKeyInfo` > `subjectPublicKey BIT String` references the RSA modulus.  However, when we view the EC key, we notice there is no modulus - different algorithm, different parameters.

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

[ecc256.badssl.com ASN.1 JavaScript Decoder](https://lapo.it/asn1js/#MIIDhjCCAwygAwIBAgISA9wz-CqbgNiNxRmepHp5hHjCMAoGCCqGSM49BAMDMDIxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQswCQYDVQQDEwJFNTAeFw0yNDA4MDkxNTA1MzZaFw0yNDExMDcxNTA1MzVaMBcxFTATBgNVBAMMDCouYmFkc3NsLmNvbTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABO1pUkMk4gM66h-alQ9_OOsdHyy7vUfON1_pCXbo_W5Qncz0VgSlEdu_EtvsJDTROZ0njIPHPWa7o6s3cTQnnQyjggIbMIICFzAOBgNVHQ8BAf8EBAMCB4AwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB_wQCMAAwHQYDVR0OBBYEFI_9xntgW2zfwTB-hT1nhI0i0LufMB8GA1UdIwQYMBaAFJ8rX888IU-dBLftKyzExnCL0tcNMFUGCCsGAQUFBwEBBEkwRzAhBggrBgEFBQcwAYYVaHR0cDovL2U1Lm8ubGVuY3Iub3JnMCIGCCsGAQUFBzAChhZodHRwOi8vZTUuaS5sZW5jci5vcmcvMCMGA1UdEQQcMBqCDCouYmFkc3NsLmNvbYIKYmFkc3NsLmNvbTATBgNVHSAEDDAKMAgGBmeBDAECATCCAQUGCisGAQQB1nkCBAIEgfYEgfMA8QB2AEiw42vapkc0D-VqAvqdMOscUgHLVt0sgdm7v6s52IRzAAABkTfiCaAAAAQDAEcwRQIhANnKy5AniVvEPBFlO9hqHjSkd72IavtXZcHHZ-TBLWdxAiAhy8FWc2ie15Nb2RsszP5uNvxQYxbx743sraNc1pUxWAB3AD8XS0_XIkdYlB1lHIS-DRLtkDd_H4Vq68G_KIXs-GRuAAABkTfiEXgAAAQDAEgwRgIhAPLTI7XUt2QST7rUIcnUbceiZOKxL43j1QqkaaocLRqhAiEA2_1cOCVy2Vo3eKvOg3dMSLEZh3GpY9I2gDbe7YOpak8wCgYIKoZIzj0EAwMDaAAwZQIwKT5oizwg-7F6vi2pb3SMRMyviZiXlpEpX5mizNwxul_-ot98KrqJmigJ-ZxAns_CAjEA-r1qIORrVbXkRBpJGcTIuRtuAFFMqi7jotmeoIxJnt3Pt3t0JyaWp_Q1Vz4cNR0I)

```
subjectPublicKeyInfo SubjectPublicKeyInfo SEQUENCE (2 elem)
        algorithm AlgorithmIdentifier SEQUENCE (2 elem)
                algorithm OBJECT IDENTIFIER 1.2.840.10045.2.1 ecPublicKey (ANSI X9.62 public key type)
                parameters ANY OBJECT IDENTIFIER 1.2.840.10045.3.1.7 prime256v1 (ANSI X9.62 named elliptic curve)
        subjectPublicKey BIT STRING (520 bit) 
```

# spki_openssl.sh

# SubjectPublicKeyInfo using OpenSSL

Using the `openssl` command we can interface with the various file types to access the public key material.  

| File Type         | Base `openssl` command     |
|-------------------|----------------------------|
| Private Key       | `openssl pkey -pubout ...` |
| Signing Request   | `openssl req -pubkey ...`  |
| Signed Public Key | `openssl x509 -pubkey ...` | 


In the below samples, we compare the thumbprints of public key material extracted from RSA private key, signing request, and public key files.  

```shell
# RSA Private Key
$ openssl pkey -pubout -inform DER -outform DER -in rsa_private-key.der | \
openssl dgst -sha256 -c

SHA2-256(stdin)= ab:a9:c4:31:a6:48:c0:0b:bc:69:fa:0d:f9:39:4b:b7:01:e9:77:14:13:f1:d0:e8:68:66:c2:9d:c4:ea:c7:2d
```
- `openssl pkey` specifies we wish to work with private and public keys.
- `-pubout` indicates we are only interested in the public key material corresponding to the private key.
- `-inform` specifies our read encoding scheme (PEM or DER)
- `-outform` specifies our output encoding scheme (PEM or DER)
- `-in` defines the file we wish to read


```shell
# RSA Signing Request
$ openssl req -pubkey -inform PEM -outform PEM -in rsa_signing-request.pem | \
sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | \
openssl asn1parse -noout -inform PEM -out /dev/stdout | \
openssl dgst -sha256 -c

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
# RSA Signed Public Key
$ openssl x509 -pubkey -inform pem -in rsa_self-signed-public-key.pem | \
sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | \
openssl asn1parse -noout -inform PEM -out /dev/stdout | \
openssl dgst -sha256 -c

SHA2-256(stdin)= ab:a9:c4:31:a6:48:c0:0b:bc:69:fa:0d:f9:39:4b:b7:01:e9:77:14:13:f1:d0:e8:68:66:c2:9d:c4:ea:c7:2d
```
- `openssl x509` to work with X.509 certificate files
- `-pubkey` to work with only the public key material
- `-inform` specifies the expected input encoding scheme
- `-in` the file to read from

Similar to the previous step, we pipe the PEM data to `sed` where the `PUBLIC KEY` portion is extracted and then fed to `openssl asn1parse` for conversion into binary form where we compute the digest.


```shell
# RSA Private Key SubjectPublicKeyInfo Digest (ASCII input, then Binary)
$ openssl pkey -pubout -inform PEM -outform DER -in rsa_private-key.pem | \
openssl dgst -sha256 -c
SHA2-256(stdin)= a1:3c:1e:5b:cb:b9:ef:17:0c:9f:fe:34:35:c7:e6:96:13:63:04:8d:c5:c1:7e:86:c0:cc:bd:35:33:30:17:0f

$ openssl pkey -pubout -inform DER -outform DER -in rsa_private-key.der | \
openssl dgst -sha256 -c

SHA2-256(stdin)= a1:3c:1e:5b:cb:b9:ef:17:0c:9f:fe:34:35:c7:e6:96:13:63:04:8d:c5:c1:7e:86:c0:cc:bd:35:33:30:17:0f

# RSA Signing Request SubjectPublicKeyInfo Digest
$ openssl req -pubkey -inform PEM -outform PEM -in rsa_signing-request.pem | \
sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | \
openssl asn1parse -noout -inform PEM -out /dev/stdout | \
openssl dgst -sha256 -c

SHA2-256(stdin)= a1:3c:1e:5b:cb:b9:ef:17:0c:9f:fe:34:35:c7:e6:96:13:63:04:8d:c5:c1:7e:86:c0:cc:bd:35:33:30:17:0f

# RSA Signed Public Key SubjectPublicKeyInfo Digest
$ openssl x509 -pubkey -inform PEM -in rsa_self-signed-public-key.pem | \
sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | \
openssl asn1parse -noout -inform PEM -out /dev/stdout | \
openssl dgst -sha256 -c

SHA2-256(stdin)= a1:3c:1e:5b:cb:b9:ef:17:0c:9f:fe:34:35:c7:e6:96:13:63:04:8d:c5:c1:7e:86:c0:cc:bd:35:33:30:17:0f
```

The same commands work just as well for Elliptic Curve keys.

```shell
# EC Private Key
$ openssl pkey -pubout -inform PEM -outform DER -in ec_private-key.pem | \
openssl dgst -sha256 -c

SHA2-256(stdin)= 1d:29:21:88:d7:6d:59:5e:da:2a:8a:3b:dd:d0:5f:ec:5e:19:7f:59:bb:e5:0a:bc:4a:e7:95:47:46:86:2b:37

# EC Signing Request
$ openssl req -pubkey -inform PEM -outform PEM -in ec_signing-request.pem | \
sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | \
openssl asn1parse -noout -inform PEM -out /dev/stdout | \
openssl dgst -sha256 -c

SHA2-256(stdin)= 1d:29:21:88:d7:6d:59:5e:da:2a:8a:3b:dd:d0:5f:ec:5e:19:7f:59:bb:e5:0a:bc:4a:e7:95:47:46:86:2b:37

# EC Signed Public Key
$ openssl x509 -pubkey -inform PEM -in ec_self-signed-public-key.pem | \
sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | \
openssl asn1parse -noout -inform PEM -out /dev/stdout | \
openssl dgst -sha256 -c

SHA2-256(stdin)= 1d:29:21:88:d7:6d:59:5e:da:2a:8a:3b:dd:d0:5f:ec:5e:19:7f:59:bb:e5:0a:bc:4a:e7:95:47:46:86:2b:37
```

You can also convert a ASCII (PEM) file into a binary encoded (DER) file and compute it's thumbprint on-demand.
```shell
$ openssl dgst -sha256 -c rsa_self-signed-public-key.der

SHA2-256(rsa_self-signed-public-key.der)= df:01:63:4a:65:8e:95:bb:17:a2:50:e4:63:35:b2:f4:36:c0:b8:75:22:c6:d4:14:be:cf:05:10:d3:da:00:c2

$ openssl x509 -inform PEM -outform DER -out /dev/stdout -in rsa_self-signed-public-key.pem | \
 openssl dgst -sha256 -c

SHA2-256(stdin)= df:01:63:4a:65:8e:95:bb:17:a2:50:e4:63:35:b2:f4:36:c0:b8:75:22:c6:d4:14:be:cf:05:10:d3:da:00:c2

```




