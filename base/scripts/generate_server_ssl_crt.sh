#!/bin/bash
 
#Required
domain=$1
commonname=$domain
servercertname=server
#Change to your company details
country=PK
state=Islamabad
locality=Islamabad
organization=pgpool.net
organizationalunit=IT
email=m.usama@gmail.com

#Optional
password=dummypassword

if [ -z "$domain" ]
then
    echo "Argument not present."
    echo "Useage $0 [common name]"
    exit 99
fi

echo "Generating key request for $domain"

#Generate a key
openssl genrsa -des3 -passout pass:$password -out ${servercertname}.key 1024 -noout

#Remove passphrase from the key. Comment the line out to keep the passphrase
echo "Removing passphrase from key"
openssl rsa -in ${servercertname}.key -passin pass:$password -out ${servercertname}.key

#Create the request
echo "Creating CRT"
openssl req -new -key ${servercertname}.key -days 3650 -out ${servercertname}.crt -x509 \
-subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"

echo "---------------------------"
echo "-----Below is your CRT-----"
echo "---------------------------"
echo
cat ${servercertname}.crt
echo "creating root certificate. using ${servercertname}.crt as root.crt"
cp ${servercertname}.crt root.crt

echo
echo "---------------------------"
echo "-----Below is your Key-----"
echo "---------------------------"
echo
cat ${servercertname}.key

