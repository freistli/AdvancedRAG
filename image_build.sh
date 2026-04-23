#!/bin/bash
set -e

if [ $# -eq 0 ]
then
echo "No arguments supplied"
docker image list
exit 1
fi


# build new image
cd ~/projects/AdvancedRAG_SVC_DEV
PYTHON_VERSION=$(uv run python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")

if [ "$PYTHON_VERSION" = "3.13" ]; then
	if ! command -v patchelf >/dev/null 2>&1; then
		echo "patchelf is required for Python 3.13 PyInstaller builds." >&2
		echo "Install it or switch to Python 3.12 with: uv python pin 3.12" >&2
		exit 1
	fi

	LIBPY=$(uv run python -c "import pathlib, sysconfig; print(pathlib.Path(sysconfig.get_config_var('LIBDIR')) / 'libpython3.13.so.1.0')")
	if [ -f "$LIBPY" ]; then
		patchelf --clear-execstack "$LIBPY"
	fi
fi

rm -rf ./build ./dist/LinuxAdvRAGSvc
uv run pyinstaller --clean ./LinuxAdvRAGSvc.spec
echo $1 > ./version.txt
echo $1 > ./dist/version.txt
cd ./dist
docker buildx build -t mwcstechstrategy/docaihub:$1 .
docker tag mwcstechstrategy/docaihub:$1 freistli/docaihub:$1
docker tag freistli/docaihub:$1 freistli/docaihub:latest
cd /mnt/c/fork/AdvancedRAG



