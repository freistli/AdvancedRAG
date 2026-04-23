#!/bin/bash

set -e

if [ $# -lt 2 ]
then
echo "Usage: $0 VERSION SUF_FIX"
docker image list
exit 1
fi

VERSION=$1
SUF_FIX=$2

# push new image
./push_to_acr.sh "$VERSION" "$SUF_FIX"

# Update Dockerfile base image tag to the release version
sed -i "s|^FROM advragmwai${SUF_FIX}.azurecr.io/docaihub:.*$|FROM advragmwai${SUF_FIX}.azurecr.io/docaihub:${VERSION}|" Dockerfile

# Update image in ACR and redeploy for the target suffix
cp .env.prod .env
./deploy_acr_app.sh "$SUF_FIX" 3 latest
./deploy_acr_app.sh "$SUF_FIX" 10 latest

