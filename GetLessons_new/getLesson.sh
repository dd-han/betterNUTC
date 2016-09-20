#!/bin/bash

TARGET_SEM='1051'
OUTPUT_FILE='unifi.html'

LESSONS='http://aisap.nutc.edu.tw/public/subject_list.js'
LESSON_DETAIL='http://aisap.nutc.edu.tw/public/day/course_list.aspx?sem='"$TARGET_SEM"'&subject='

echo ' ' > $OUTPUT_FILE

curl "$LESSONS" | grep '\_'"$TARGET_SEM" | sed 's/[^=]*\= //g' | sed 's/;$//g' | sed 's/^\[//g' | sed 's/\] //g' | sed 's/\],\[/]\n[/g' | sed 's/^\[//g' | sed 's/\]$//g' > temp.lst

for i in `cat temp.lst`;do
    ID=`cut -f 1 -d ',' <<< $i | sed 's/\"//g'`

    curl "${LESSON_DETAIL}${ID}" > page.html
    TABLE_START_LINE=`cat page.html | grep 'grid_view empty_html' -n | sed 's/:.*//g'`
    TABLE_LINES=`cat page.html | sed -n "${TABLE_START_LINE},"'$p' | grep '</table>' -n | sed 's/:.*//g'`
    TABLE_LINES=$(( $TABLE_LINES - 1 ))

    CONTENT_ROW_START=`cat page.html | sed -n "${TABLE_START_LINE},+${TABLE_LINES}p" | grep '<tr>' -n | sed -n '1,1p' | sed 's/:.*//g' `
    CONTENT_ROW_START=$(( $CONTENT_ROW_START + $TABLE_START_LINE -1 ))
    CONTENT_ROW_LINES=`cat page.html | sed -n "${TABLE_START_LINE},+${TABLE_LINES}p" | grep '<tr>' -n | sed -n '$,1p' | sed 's/:.*//g' `
    CONTENT_ROW_LINES=$(( $CONTENT_ROW_LINES -2 ))

    cat page.html | sed -n "${CONTENT_ROW_START},+${CONTENT_ROW_LINES}p" >> $OUTPUT_FILE
    rm page.html

    echo "ID=$ID"
    echo "LINE=$TABLE_START_LINE,$TABLE_LINES"
    echo "CONTENT=${CONTENT_ROW_START},$CONTENT_ROW_LINES"
done

rm temp.lst
