#!/bin/bash

SCRIPT_VERSION="v0.0.8"

# Description:
#   A proof-of-concept script that uses OpenSSL to generate message digests
#   (thumbprints) for X.509 certificate files (e.g., private keys, signing
#   requests, signed public keys). The script also provides thumbprints
#   representing the subjectPublicKeyInfo (SPKI) for each file processed,
#   including public key pins in base64 format for HPKP use cases.


# Global variables
error_log=() # Array to store error messages

digest_algorithm="SHA256"
x509_private_key=''
x509_signed_public_key=''
x509_signing_request=''
working_folder=$(pwd)



usage() {
cat <<EOF
Usage: $(basename "$0") (options)

Description:
    A proof-of-concept script that uses OpenSSL to generate message digests 
    (thumbprints) for X.509 certificate files (e.g., private keys, signing 
    requests, signed public keys). The script also provides thumbprints 
    representing the subjectPublicKeyInfo (SPKI) data corresponding to the file,
    including public key pins in base64 format for HTTP Public Key Pinning (HPKP).

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

Examples:
    $(basename "$0") --signed-public-key cert.pem
    $(basename "$0") --private-key key.pem --digest-algorithm sha1

EOF
}


check_dependencies() {
    local return_status=0

    printf "Checking Dependencies:\n"

    # check for OpenSSL
    # if failure, increment return_status
    check_openssl
    (( return_status += $? ))

    printf "\n"

    return $return_status
}


# checks to ensure OpenSSL exits
check_openssl(){
    local return_status=0

    printf "  openssl... "

    type openssl > /dev/null 2>&1
    return_status=$?

    if [[ $return_status -ne 0 ]]; then
        error_log+=("Warning: OpenSSL could not be found.")
        printf "fail!\n"
    else
        printf "success (%s)\n" "$(openssl version | head -n 1)"
    fi

    return
}


show_parameters() {
    printf "Parameters:\n"
    printf "  Private Key        %s\n" "$x509_private_key"
    printf "  Signing Request    %s\n" "$x509_signing_request"
    printf "  Signed Public Key  %s\n" "$x509_signed_public_key"
    printf "  Working Folder      %s\n" "$working_folder"
    printf "\n"
}


# Display information about the private key file.
show_private_key_info() {
    printf "Private Key Digests:\n"

    file_type=$(file "$x509_private_key" | awk -F ': ' '{print $2}')

    # Thumbprint of the entire binary (DER) file.
    certificate_thumbprint=$(
        openssl dgst -"$digest_algorithm" -c "$x509_private_key" | 
        awk '{print $2}')

    # Thumbprint of the subjectPublicKeyInfo (SPKI) derived from the source private key.

    # There is a disrepancy between macOS and Linux (Kali) versions of `file` commmand.  
    # macOS: file --version   file-5.45
    # Kali:  file --version   file-5.41
    # 
    # With macOS, the ASCII (PEM) encoded private key is identified as 'ASCII text'.
    # With Kali, the ASCII (PEM) encoded private key is identified as 'OpenSSH private key (no password)'.
    # 
    # Noted here in the event there are additional permutations of ASCII key files.
    if [[ "$file_type" == "ASCII"* ]] || [[ "$file_type" == "OpenSSH private key"* ]] || [[ "$file_type" == "PEM"* ]]; then
        spki_thumbprint=$(openssl pkey -pubout -inform PEM -outform DER -in "$x509_private_key" | 
            openssl dgst -"$digest_algorithm" -c | 
            awk '{print $2}')
        pubkey_pin=$(openssl pkey -pubout -inform PEM -outform DER -in "$x509_private_key" | 
            openssl dgst -"$digest_algorithm" -binary | base64)
    else
        spki_thumbprint=$(openssl pkey -pubout -inform DER -outform DER -in "$x509_private_key" | 
            openssl dgst -"$digest_algorithm" -c | 
            awk '{print $2}')
        pubkey_pin=$(openssl pkey -pubout -inform DER -outform DER -in "$x509_private_key" | 
            openssl dgst -"$digest_algorithm" -binary | base64)
    fi

    # Calculate both PEM and DER file thumbprints regardless of source format
    if [[ "$file_type" == "ASCII"* ]] || [[ "$file_type" == "OpenSSH private key"* ]] || [[ "$file_type" == "PEM"* ]]; then
        # Source is PEM, calculate DER thumbprint by converting
        pem_thumbprint="$certificate_thumbprint"
        der_thumbprint=$(openssl pkey -inform PEM -outform DER -in "$x509_private_key" | 
            openssl dgst -"$digest_algorithm" -c | awk '{print $2}')
    else
        # Source is DER, calculate PEM thumbprint by converting
        der_thumbprint="$certificate_thumbprint"
        pem_thumbprint=$(openssl pkey -inform DER -outform PEM -in "$x509_private_key" | 
            openssl dgst -"$digest_algorithm" -c | awk '{print $2}')
    fi

    printf "         File Path: %s\n" "$x509_private_key"
    printf "         File Type: %s\n" "$file_type"
    printf "   File Thumbprint:\n"
    printf "               DER: (%s) %s\n" "$digest_algorithm" "$der_thumbprint"
    printf "               PEM: (%s) %s\n" "$digest_algorithm" "$pem_thumbprint"
    printf "   SPKI Thumbprint: (%s) %s\n" "$digest_algorithm" "$spki_thumbprint"
    printf "    Public Key Pin: (%s) %s\n" "$digest_algorithm" "$pubkey_pin"
    printf "\n"
}


show_signing_request_info() {
    printf "Signing Request Digests:\n"

    file_type=$(file "$x509_signing_request" | awk -F ': ' '{print $2}')

    # Thumbprint of the entire file.
    csr_thumbprint=$(
        openssl dgst -"$digest_algorithm" -c "$x509_signing_request" | 
        awk '{print $2}')

    # Thumbprint of the subjectPublicKeyInfo (SPKI) extracted from the signing request.

    # IF file_type begins with PEM, then the file is a PEM file.
    if [[ "$file_type" == "PEM"* ]]; then
        spki_thumbprint=$(openssl req -pubkey -inform PEM -outform PEM -in "$x509_signing_request" | 
            sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | 
            openssl asn1parse -noout -inform PEM -out /dev/stdout | 
            openssl dgst -"$digest_algorithm" -c | awk '{print $2}')
        pubkey_pin=$(openssl req -pubkey -inform PEM -outform PEM -in "$x509_signing_request" | 
            sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | 
            openssl asn1parse -noout -inform PEM -out /dev/stdout | 
            openssl dgst -"$digest_algorithm" -binary | base64)
    else
        spki_thumbprint=$(openssl req -pubkey -inform DER -outform PEM -in "$x509_signing_request" | 
            sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | 
            openssl asn1parse -noout -inform PEM -out /dev/stdout | 
            openssl dgst -"$digest_algorithm" -c | awk '{print $2}')
        pubkey_pin=$(openssl req -pubkey -inform DER -outform PEM -in "$x509_signing_request" | 
            sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | 
            openssl asn1parse -noout -inform PEM -out /dev/stdout | 
            openssl dgst -"$digest_algorithm" -binary | base64)
    fi

    # Calculate both PEM and DER file thumbprints regardless of source format
    if [[ "$file_type" == "PEM"* ]]; then
        # Source is PEM, calculate DER thumbprint by converting
        pem_thumbprint="$csr_thumbprint"
        der_thumbprint=$(openssl req -inform PEM -outform DER -in "$x509_signing_request" | 
            openssl dgst -"$digest_algorithm" -c | awk '{print $2}')
    else
        # Source is DER, calculate PEM thumbprint by converting
        der_thumbprint="$csr_thumbprint"
        pem_thumbprint=$(openssl req -inform DER -outform PEM -in "$x509_signing_request" | 
            openssl dgst -"$digest_algorithm" -c | awk '{print $2}')
    fi

    printf "         File Path: %s\n" "$x509_signing_request"
    printf "         File Type: %s\n" "$file_type"
    printf "   File Thumbprint:\n"
    printf "               DER: (%s) %s\n" "$digest_algorithm" "$der_thumbprint"
    printf "               PEM: (%s) %s\n" "$digest_algorithm" "$pem_thumbprint"
    printf "   SPKI Thumbprint: (%s) %s\n" "$digest_algorithm" "$spki_thumbprint"
    printf "    Public Key Pin: (%s) %s\n" "$digest_algorithm" "$pubkey_pin"
    printf "\n"
}


show_signed_public_key_info() {
    printf "Signed Public Key Digests:\n"

    file_type=$(file "$x509_signed_public_key" | awk -F ': ' '{print $2}')

    # Thumbprint of the entire binary (DER) file.
    certificate_thumbprint=$(
        openssl dgst -"$digest_algorithm" -c "$x509_signed_public_key" | 
        awk '{print $2}')

    # Thumbprint of the subjectPublicKeyInfo (SPKI) extracted from the signed public key.

    if [[ "$file_type" == "PEM"* ]]; then
        spki_thumbprint=$(openssl x509 -pubkey -inform PEM -in "$x509_signed_public_key" | 
            sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | 
            openssl asn1parse -noout -inform PEM -out /dev/stdout | 
            openssl dgst -"$digest_algorithm" -c | awk '{print $2}')
        pubkey_pin=$(openssl x509 -pubkey -inform PEM -in "$x509_signed_public_key" | 
            sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | 
            openssl asn1parse -noout -inform PEM -out /dev/stdout | 
            openssl dgst -"$digest_algorithm" -binary | base64)
    else
        spki_thumbprint=$(openssl x509 -pubkey -inform DER -in "$x509_signed_public_key" | 
            sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | 
            openssl asn1parse -noout -inform PEM -out /dev/stdout | 
            openssl dgst -"$digest_algorithm" -c | awk '{print $2}')
        pubkey_pin=$(openssl x509 -pubkey -inform DER -in "$x509_signed_public_key" | 
            sed -n '/BEGIN\ PUBLIC\ KEY/,/END\ PUBLIC\ KEY/p' | 
            openssl asn1parse -noout -inform PEM -out /dev/stdout | 
            openssl dgst -"$digest_algorithm" -binary | base64)
    fi

    # Calculate both PEM and DER file thumbprints regardless of source format
    if [[ "$file_type" == "PEM"* ]]; then
        # Source is PEM, calculate DER thumbprint by converting
        pem_thumbprint="$certificate_thumbprint"
        der_thumbprint=$(openssl x509 -inform PEM -outform DER -in "$x509_signed_public_key" | 
            openssl dgst -"$digest_algorithm" -c | awk '{print $2}')
    else
        # Source is DER, calculate PEM thumbprint by converting
        der_thumbprint="$certificate_thumbprint"  
        pem_thumbprint=$(openssl x509 -inform DER -outform PEM -in "$x509_signed_public_key" | 
            openssl dgst -"$digest_algorithm" -c | awk '{print $2}')
    fi

    printf "         File Path: %s\n" "$x509_signed_public_key"
    printf "         File Type: %s\n" "$file_type"
    printf "   File Thumbprint:\n"
    printf "               DER: (%s) %s\n" "$digest_algorithm" "$der_thumbprint"
    printf "               PEM: (%s) %s\n" "$digest_algorithm" "$pem_thumbprint"
    printf "   SPKI Thumbprint: (%s) %s\n" "$digest_algorithm" "$spki_thumbprint"
    printf "    Public Key Pin: (%s) %s\n" "$digest_algorithm" "$pubkey_pin"
    printf "\n"
}


# displays any errors in the error log
check_errors() {
    # print any errors that might have been encountered.
    total_errors=${#error_log[@]}
    if [ "${total_errors}" -gt 0 ]; then
        printf "Error(s) encountered: (%d)\n" "${total_errors}"
        for (( i=0; i<"$total_errors"; i++)) do
            printf " %2d: %s\n" "$((i + 1))" "${error_log[$i]}"
        done

        printf "\n"
        return 1
    fi
}


main() {
    printf "\n"
    printf "   Script: %s (%s)\n" "$(basename "$0")" "$SCRIPT_VERSION"
    printf "Timestamp: %s\n" "$(date +"%Y-%m-%d %H:%M:%S %Z")"
    printf "\n"
   
    # if no arguments are passed, then display the usage
    if [ "$#" -eq 0 ]; then
        error_log+=("Error: Choose one or more required options.")
        usage
        exit 1
    fi

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            --private-key)
                x509_private_key=$2
                shift; shift
                ;;
            --signing-request)
                x509_signing_request=$2
                shift; shift
                ;;
            --signed-public-key)
                x509_signed_public_key=$2
                shift; shift
                ;;
            --working-folder)
                working_folder=$2
                shift; shift
                ;;
            --digest-algorithm)
                digest_algorithm=$(echo "$2" | tr '[:lower:]' '[:upper:]')
                shift; shift
                ;;
            *)
                error_log+=("Unknown option: $1")
                usage
                exit 1
                ;;
        esac
    done



    check_dependencies

    #show_parameters

    # if x509_private_key is set, then show the private key information
    if [ -n "$x509_private_key" ]; then
        # if file exists, then show the private key information
        if [ -f "$x509_private_key" ]; then
            show_private_key_info
        else
            error_log+=("Error: Private key file not found.")
        fi
    fi

    # if x509_signing_request is set, then show the signing request information
    if [ -n "$x509_signing_request" ]; then
        # if file exists, then show the signing request information
        if [ -f "$x509_signing_request" ]; then
            show_signing_request_info
        else
            error_log+=("Error: Signing request file not found.")
        fi
    fi

    if [ -n "$x509_signed_public_key" ]; then
        # if file exists, then show the signed public key information
        if [ -f "$x509_signed_public_key" ]; then
            show_signed_public_key_info
        else
            error_log+=("Error: Signed public key file not found.")
        fi
    fi


}


main "$@"
check_errors