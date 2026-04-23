#!/bin/bash
set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 VERSION SUF_FIX"
  echo "  VERSION   Image version tag (e.g. 1.2.8)"
  echo "  SUF_FIX   Suffix used for ACR naming (e.g. dev02)"
  exit 1
fi

VERSION=$1
SUF_FIX=$2
ORAG_NAME="mwai"
ACR_NAME="advrag${ORAG_NAME}${SUF_FIX}"
ACR_SERVER="${ACR_NAME}.azurecr.io"
LOCAL_IMAGE="freistli/docaihub"
REMOTE_IMAGE="${ACR_SERVER}/docaihub"

echo "Logging in to ACR: $ACR_NAME"
ACR_TOKEN=$(az acr login --name $ACR_NAME --expose-token --output tsv --query accessToken)
docker login $ACR_SERVER --username 00000000-0000-0000-0000-000000000000 --password-stdin <<< "$ACR_TOKEN"

echo "Tagging ${LOCAL_IMAGE}:${VERSION} -> ${REMOTE_IMAGE}:${VERSION}"
docker tag "${LOCAL_IMAGE}:${VERSION}" "${REMOTE_IMAGE}:${VERSION}"

echo "Tagging ${LOCAL_IMAGE}:latest -> ${REMOTE_IMAGE}:latest"
docker tag "${LOCAL_IMAGE}:latest" "${REMOTE_IMAGE}:latest"

echo "Pushing ${REMOTE_IMAGE}:${VERSION}"
docker push "${REMOTE_IMAGE}:${VERSION}"

echo "Pushing ${REMOTE_IMAGE}:latest"
docker push "${REMOTE_IMAGE}:latest"

echo "Done."
