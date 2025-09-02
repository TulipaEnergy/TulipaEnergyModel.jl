#!/bin/bash

docker run --rm -v $PWD:/data --user $(id -u):$(id -g) --env JOURNAL=joss openjournals/inara
