#!/bin/bash
COUNT=1
# bash until loop
until [ $COUNT -gt 8 ]; do
	echo $COUNT
        echo `stack exec -- SugarScapeSTMTArray +RTS -N4 > dump.txt`
        let COUNT=COUNT+1
done 
