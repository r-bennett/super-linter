#!/usr/bin/env bash
################################################################################
########################### Install Python Dependencies ########################
################################################################################

#####################
# Set fail on error #
#####################
set -euo pipefail

########################################
# Install basic libs to run installers #
########################################
pip install pipx

#########################################################
# Iterate through requirements.txt to install binaries #
#########################################################
while read -r line; do
  # Install dependency
  pipx install "${line}"
done <requirements.txt
