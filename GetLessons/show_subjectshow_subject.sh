#!/bin/bash
BRW_UA="Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)"
BRW_REF="http://academic.nutc.edu.tw/curriculum/show_subject/show_subject_form.asp"
ENC_CONV="iconv -f big5 -t utf8"
LN_CONV="sed s/\\r//g"
SAV_COOKIE="cookie.txt"
OUTPUT="LessonLits.txt"

function ChineseNumber() {
	case $1 in
		"0")
			echo "日"
			;;
		"1")
			echo "一"
			;;
		"2")
			echo "二"
			;;
		"3")
			echo "三"
			;;
		"4")
			echo "四"
			;;
		"5")
			echo "五"
			;;
		"6")
			echo "六"
			;;
		"7")
			echo "七"
			;;
		*)
			echo "謎"
			;;
	esac
}

function conv_2_big5(){
	## 編碼轉換
	echo $1 | iconv -f utf8 -t big5
}

function tab_header(){
	## 只是產生標題列而已XD
	echo "學制	修課班級	學年/學期	必選修	TIMETABLE_URL	上課時間	修課科目	授課老師	學分數	時數	修課人數	教學大綱" > "$OUTPUT"
}

function get_lesson(){
	get_list COOKIES
	
	## 取得課程清單
	curl http://academic.nutc.edu.tw/curriculum/show_subject/check_show_select_step2.asp -D "cookie1.txt" -b "$SAV_COOKIE" -A "$BREW_UA" -e "$BRW_REF" -d "show_select2=$(conv_2_big5 $1)&SUB_CHI_NAME=&Submit=%B6%7D%A9l%ACd%B8%DF%B8%EA%AE%C6" > /dev/null
	#curl http://academic.nutc.edu.tw/curriculum/show_subject/check_show_select_step2.asp -D "cookie1.txt" -b "$SAV_COOKIE" -A "$BREW_UA" -e "$BRW_REF" -d "show_select2=2D%B6i%B6%A5%B9q%B8%A3%B0%CA%B5e&Submit=%B6%7D%A9l%ACd%B8%DF%B8%EA%AE%C6" > /dev/null
	curl http://academic.nutc.edu.tw/curriculum/show_subject/show_subject_choose.asp -b "cookie1.txt" -A "$BREW_UA" -e "$BRW_REF" | $ENC_CONV -c > show_subject_choose.asp 
	#rm "cookie1.txt"
	
	## 把HTML變成以tab分隔的txt
	cat show_subject_choose.asp | sed s/\\r//g | grep table | sed s/\<\\/TR\>/\\n/g | grep -v 修課班級 | \
	sed s/\<\\/TD\>/\\t/g | sed s/\<a[^=]*\.[^\?]*//g |  sed s/\ \>教學大綱"<\/a>"//g | \
	sed s/\<a[^=]*=rot_title_time\.asp//g | sed -e :a -e 's/<[^>]*>//g;/</N;//ba' | sed -e s/"?class[^>]*>"//g | \
	sed -e s/'※.*'//g | sed -e s/'此科'/$1/g | grep -v '^ *$' | sed s/\ \>/\\t/g  >> ${OUTPUT}
	#rm show_subject_choose.asp
}

function get_list(){
	## 取得一份完整的課程清單
	curl http://academic.nutc.edu.tw/curriculum/show_subject/show_subject_form.asp?show_vol=2 -D "$SAV_COOKIE" -A "$BREW_UA" -e "$BRW_REF" | $ENC_CONV > /dev/null
	curl http://academic.nutc.edu.tw/curriculum/show_subject/check_show_select.asp -D $SAV_COOKIE -b "$SAV_COOKIE" -A "$BREW_UA" -e "$BRW_REF" -d "show_radio=2&show_select6=3&show_select7=3&show_select8=3&Submit=%A1%40%A4U%A1%40%A4%40%A1%40%A8B%A1%40" | $ENC_CONV > /dev/null
	curl http://academic.nutc.edu.tw/curriculum/show_subject/show_subject_form_step2.asp -b "$SAV_COOKIE" -A "$BREW_UA" -e "$BRW_REF" | $ENC_CONV > show_subject_form_step2.asp 

	if [ "$1" != "COOKIES" ];then
	
		## 搜尋網頁第幾行有課程內容
		DATA_LINE=$(cat show_subject_form_step2.asp  | grep show_select2 -n | sed s/\:.*//g)
		DATA_LINE=$(($DATA_LINE+1))
		
		## 講網頁表格格式轉換成簡單的文字清單
		cat show_subject_form_step2.asp | sed s/\\r//g | sed -n $DATA_LINE,$DATA_LINE"p" | sed 's/<option[^>]*>/\n/g' | sed -e :a -e 's/<[^>]*>//g;/</N;//ba' | grep -v '^ *$' | sed s/\ $//g | sed s/$//g > Lessons.lst
		
	fi
	rm show_subject_form_step2.asp 
}

function list_URL(){
	## 把表格攤平，取出有網址的那幾行
	cat "$OUTPUT" | sed s/\\t/\\n/g | grep flow_no > URL.txt
	cat URL.txt | sed s/?flow_no/'http:\/\/academic.nutc.edu.tw\/curriculum\/show_subject\/rot_show_teach_flow.asp?flow_no'/g > FullURL.txt
}

function list_URL_TIME(){
	## 把表格攤平，取出有網址的那幾行
	cat "$OUTPUT" | sed s/\\t/\\n/g | grep title_no > URL_TIME.txt
}

function get_LessTime() {
	## 取得單一課程的上課時間
	curl "http://academic.nutc.edu.tw/curriculum/show_subject/rot_title_time.asp"$1 -D "$SAV_COOKIE" -A "$BREW_UA" -e "$BRW_REF" > /dev/null
	curl "http://academic.nutc.edu.tw/curriculum/show_subject/title_time.asp" -b "$SAV_COOKIE" -A "$BREW_UA" -e "$BRW_REF" | $ENC_CONV > time.html
	rm "$SAV_COOKIE"
	
	## 將課表網頁下載後，取出表格、表格每一格都獨立成一列後，刪除無意義第一行，清除無意義的第N節、時間、詭異符號後清除html標籤
	## 完成後再用grep過濾有字的那幾行並顯示行號後，行號後面的字元刪除
	cat time.html | sed s/\\r//g | grep \<TR | sed "s/<TD[^>]*>/\\n/g" | sed -n 2,73p | sed s/第.節//g | sed s/│//g | sed s/..\:..//g | sed -e :a -e 's/<[^>]*>//g;/</N;//ba' |grep -n [一二三四五六七] | sed s/:.*$//g > time.txt
	#rm time.html
	
	## 處理完後計算表格位置
	## 每一列分別是第N節、時間、星期一、星期二、星期三、星期四、星期五、星期六、星期日，共九個欄位
	## 所以%9-2=星期N  /9+1=第N節課
	time=""
	for LINE in $(cat time.txt)
	do
		week=$(expr $LINE % 9 )
		[ "$week" == "0" ] && week=9
		week=$(expr $week - 2 )
		week=$(ChineseNumber $week)
		
		no=$(expr $LINE - 2)
		no=$(expr $no / 9 + 1)
		
		time=$time$week$no
	done
	#rm time.txt

	URL="http://academic.nutc.edu.tw/curriculum/show_subject/rot_title_time.asp${1}"
	sed -i "s/$1/$1	$time/g" "$OUTPUT"
}

## 取得課程清單"$OUTPUT"
get_list

## 產生標題列後開始取得各個課程資訊
tab_header
for LESSON_NAME in $(cat Lessons.lst | sed s/\ /+/g)
do	
	get_lesson $LESSON_NAME
	#echo $LESSON_NAME
done
rm Lessons.lst
rm "cookie1.txt"
rm "show_subject_choose.asp"

## Clear Main Cookies
rm $SAV_COOKIE

## 取得網址清單準備開始查時間
list_URL_TIME
cp "LessonLits.txt" "LessonLits_noTime.txt"

## 開始查時間
for URL in $(cat URL_TIME.txt)
do
	#echo "http://academic.nutc.edu.tw/curriculum/show_subject/rot_title_time.asp"$URL
	get_LessTime "$URL"
done
rm time.html
rm time.txt
rm URL_TIME.txt

cat LessonLits.txt | sed s/\\t/\",\"/g | sed s/^/\"/g | sed s/$/\"/g > LessonLits.csv
