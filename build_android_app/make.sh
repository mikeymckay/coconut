#!/bin/bash
# Edit this file to match your folders


echo Clean out the coconut DB of any existing assessments or results
echo "Delete the existing zanzibar database"
curl -H "Content-Type: application/json" -X DELETE http://coco:cocopuffs@localhost:5984/zanzibar; 
echo "Create a new, empty  zanzibar database"
curl -H "Content-Type: application/json" -X PUT http://coco:cocopuffs@localhost:5984/zanzibar; 
cd ..; 
echo "Push into the zanzibar database a fresh copy from the current source code"
couchapp push; 
cd -

curl -H "Content-Type: application/json" -d '{"mode":"mobile","collection":"local_configuration"}' -X PUT http://coco:cocopuffs@localhost:5984/zanzibar/coconut.config.local; 

curl --compressed -s http://coconut.zmcp.org/zanzibar/Facility%20Hierarchy > /tmp/Facility\ Hierarchy.json
curl -H "Content-Type: application/json" -d @/tmp/Facility\ Hierarchy.json -X PUT http://coco:cocopuffs@localhost:5984/zanzibar/Facility%20Hierarchy

curl --compressed -s http://coconut.zmcp.org/zanzibar/Ward%20Hierarchy > /tmp/Ward\ Hierarchy.json
curl -H "Content-Type: application/json" -d @/tmp/Ward\ Hierarchy.json -X PUT http://coco:cocopuffs@localhost:5984/zanzibar/Ward%20Hierarchy

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
curl -X POST -H "Content-Type: application/json" http://coco:cocopuffs@localhost:5984/zanzibar/_compact
echo
echo "********"
echo "Building"
echo "********"
ant debug
NOW=$(date +"%Y%m%d-%H")
VERSION=`curl http://localhost:5984/zanzibar/_changes | grep _design | sed s/^.*\"rev\":\"// | sed s/\".*// | sed s/-............................../-/`
cp bin/CoconutSurveillance-debug.apk bin/Coconut-$VERSION-$NOW.apk
echo 
echo "************"
echo "Uninstalling"
echo "************"
adb uninstall org.rti.coconut.surveillance
echo
echo "**********"
echo "Installing"
echo "**********"
adb install bin/CoconutSurveillance-debug.apk
echo
echo "**********"
echo "Backing up to $HOME/$BACKUP"
echo "**********"

#adb shell am start -n com.couchbase.callback/.AndroidCouchbaseCallback
