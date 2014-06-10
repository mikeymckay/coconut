#!/bin/bash
# Edit this file to match your folders

echo Clean out the schoolnet DB of any existing assessments or results
echo "Delete the existing schoolnet database"
curl -H "Content-Type: application/json" -X DELETE http://coco:cocopuffs@localhost:5984/schoolnet; 
echo "Create a new, empty schoolnet database"
curl -H "Content-Type: application/json" -X PUT http://coco:cocopuffs@localhost:5984/schoolnet; 
cd ..; 
echo "Push into the database a fresh copy from the current source code"
couchapp push; 
curl -H "Content-Type: application/json" -d '{"mode":"mobile","collection":"local_configuration"}' -X PUT http://coco:cocopuffs@localhost:5984/schoolnet/coconut.config.local; 
cd -


echo
echo "********"
echo "Cleaning"
echo "********"
ant clean
# ant debug clean
echo
echo "********"
echo "Compacting database"
echo "********"
curl -X POST -H "Content-Type: application/json" http://coco:cocopuffs@localhost:5984/schoolnet/_compact
echo
echo "********"
echo "Building"
echo "********"
ant debug
NOW=$(date +"%Y%m%d-%H")
VERSION=`cat ../_attachments/version`
cp bin/Coconut-debug.apk bin/Coconut-$VERSION-$NOW.apk
echo 
echo "************"
echo "Uninstalling"
echo "************"
adb uninstall com.couchbase.callback
echo
echo "**********"
echo "Installing"
echo "**********"
adb install bin/Coconut-debug.apk
echo
echo "**********"
echo "Backing up to $HOME/$BACKUP"
echo "**********"

#adb shell am start -n com.couchbase.callback/.AndroidCouchbaseCallback
