#!/bin/bash

netstat -tnp |tail -n +3 | tr -s " " |cut -d " " -f 6  |sort |uniq -c 
