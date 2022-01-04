#!/usr/bin/env bash
################################################################################
########################### Install Python Dependancies ########################
################################################################################

#####################
# Set fail on error #
#####################
set -euo pipefail

########################################
# Install basic libs to run installers #
########################################
pip install pipx
pipx ensurepath

#########################################################
# Itterate through requirments.txt to install bainaries #
#########################################################
while read -r line; do
  # Install dependency
  pipx install "${line}"
done <requirements.txt
