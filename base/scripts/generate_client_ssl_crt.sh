#!/bin/bash
 
#Required
dbname=$1
commonname=$dbname
clientcertname=postgresql
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

if [ -z "$dbname" ]
then
    echo "Argument not present."
    echo "Useage $0 [database name]"
    exit 99
fi

echo "Generating key request for $dbname"

#Generate a key
openssl genrsa -des3 -passout pass:$password -out ${clientcertname}.key 1024 -noout

#Remove passphrase from the key. Comment the line out to keep the passphrase
echo "Removing passphrase from key"
openssl rsa -in ${clientcertname}.key -passin pass:$password -out ${clientcertname}.key

#Create the request
echo "Creating CSR"
openssl req -new -key ${clientcertname}.key -out ${clientcertname}.csr -subj "/C=$country/ST=$state/L=$locality/O=$organization/CN=$commonname"

echo "Creating CRT"
openssl x509 -req -in ${clientcertname}.csr -CA root.crt -CAkey ${servercertname}.key -out ${clientcertname}.crt -CAcreateserial

echo "---------------------------"
echo "-----Below is your CRT-----"
echo "---------------------------"
echo
cat ${clientcertname}.crt

