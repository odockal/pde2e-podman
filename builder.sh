#!/bin/bash

# Build Mac OS image
echo "### Building and pushing darwin image ###"
OS=darwin make oci-build
OS=darwin make oci-push

# Build Windows image
echo "### Building and pushing windows image ###"
OS=windows make oci-build
OS=windows make oci-push


