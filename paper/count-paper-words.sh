#!/bin/bash

awk '/## Summary/,EOF { print $0}' paper.md | wc -w
