#!/bin/bash
################################################################################
##  File:  hosted-tool-cache.sh
##  Desc:  Downloads and installs hosted tools cache
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/document.sh

# Fail out if any setups fail
set -e

AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
mkdir $AGENT_TOOLSDIRECTORY
echo "AGENT_TOOLSDIRECTORY=$AGENT_TOOLSDIRECTORY" | tee -a /etc/environment

chmod -R 777 $AGENT_TOOLSDIRECTORY

echo "Installing npm-toolcache..."

toolVersionsFileContent=$(cat "$INSTALLER_SCRIPT_FOLDER/toolcache.json")
tools=$(echo $toolVersionsFileContent | jq -r 'keys | .[]')

for tool in ${tools[@]}; do
    toolVersions=$(echo $toolVersionsFileContent | jq -r ".[\"$tool\"] | .[]")

    for toolVersion in ${toolVersions[@]}; do
        IFS='-' read -ra toolName <<< "$TOOL"

        echo "Install ${toolName[1]} - v.$toolVersion"

        toolVersionToInstall=$(printf "$tool" "1804" "$toolVersion")
        npm install $toolVersionToInstall --registry=$TOOLCACHE_REGISTRY
    done;
done;

DocumentInstalledItem "Python:"
pythons=$(ls $AGENT_TOOLSDIRECTORY/Python)
for python in $pythons; do
	DocumentInstalledItemIndent "Python $python"
done;

DocumentInstalledItem "Ruby:"
rubys=$(ls $AGENT_TOOLSDIRECTORY/Ruby)
for ruby in $rubys; do
	DocumentInstalledItemIndent "Ruby $ruby"
done;

DocumentInstalledItem "PyPy:"
pypys=$(ls $AGENT_TOOLSDIRECTORY/PyPy)
for pypy in $pypys; do
	DocumentInstalledItemIndent "PyPy $pypy"
done;
