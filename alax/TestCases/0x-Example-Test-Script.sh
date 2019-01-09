#!/bin/bash

logfile="Example-Log-File.log"
testresult=true

echo "Introduction to the script ..."			>  $logfile

printf "\n" >> $logfile
echo "Checking test step #1 ..."			>> $logfile



if [[ "$testresult" == "true" ]]; then
        echo TEST PASSED
else
        echo TEST FAILED
fi
