#!/bin/bash

PNG_TOOL_DIR=`pwd`
LOG_FILE=$PNG_TOOL_DIR/log.txt

help_cmd()
{
	echo "usage: sh ScriptPNG.sh dir"
	echo "usage: sh ScriptPNG.sh png_file"
}

if [ "$1" = '-help' ]; then
	help_cmd
	exit 1
fi

# process_png backup_png
compress_png()
{
	process_png=$1
	backup_png=$2
	wine_fileName=`winepath -w $process_png`

	echo " => process $process_png $backup_png ..."

	echo ' ---------------- ' 1>>$LOG_FILE
    echo "fileName->$process_png" 1>>$LOG_FILE
    #step 1 :
    wine $PNG_TOOL_DIR/lib/truepng -f0,5 -i0 -g0 -a0 -md remove all -zc7 -zm4-9 -zs0-3 -force -y $wine_fileName 1>/tmp/temp
    zmAndZs=`tail -2 /tmp/temp | awk '{print $2} {print $3}' | awk -F ':' '{print $2}'`
    arr=$(echo $zmAndZs | tr " " "\n")
    count=0
    for item in $arr; do
    	let count++
    	if [ $count -eq 1 ]; then
    		let memlevel=item
    		echo "zlib-memlevel->"$memlevel 1>>$LOG_FILE
    	elif [ $count -eq 2 ]; then
    		let strategy=item
    		echo "zlib-strategy->"$strategy 1>>$LOG_FILE
    	fi
    done

    if [ $count -ne 2 ]; then
    	echo can not get zlib-memlevel and zlib-strategy 1>>$LOG_FILE
    	exit 1
    fi

    #step 2 : 
    pnginfo=`wine $PNG_TOOL_DIR/lib/pngout -l $wine_fileName | awk '{print $1}'`
    colortypes=$(echo $pnginfo | tr "c" "\n")
    let count=0
    for item in $colortypes; do
    	let count++
    	if [ $count -eq 2 ]; then
    		let colortype=item
    		echo "colortype->"$colortype 1>>$LOG_FILE
    	fi
    done

    if [ $count -ne 2 ]; then
    	echo can not get colortype 1>>$LOG_FILE
		exit 1
    fi

    #step 3 :
    if [ $colortype -eq 6 ]; then
        wine $PNG_TOOL_DIR/lib/cryopng -for -q -zc7 -zm1 -zs1 -f1 $process_png
    fi

    zip_compression=2
    fileSize=$(ls -ld $process_png | awk '{print int($5)}')
    echo "fileSize->"$fileSize 1>>$LOG_FILE
    if [ $fileSize -ge 65536 ]; then
        let zip_compression=1
    elif [ $fileSize -le 16384 ]; then
        let zip_compression=4
    fi
    echo "zip_compression->"$zip_compression 1>>$LOG_FILE

    wine $PNG_TOOL_DIR/lib/pngwolf --in=$process_png --out=$process_png --max-stagnate-time=0 --max-evaluations=1 --zlib-level=7 --zlib-strategy=$strategy --zlib-window=15 --zlib-memlevel=$memlevel --7zip-mpass=$zip_compression --even-if-bigger
    wine $PNG_TOOL_DIR/lib/deflopt -k -b -s $wine_fileName

    #step 4 : 
    #    compare fileSize and choose the best png
	afterFileSize=$(ls -ld $process_png | awk '{print int($5)}')
	beforeFileSize=$(ls -ld $backup_png | awk '{print int($5)}')
	reduceSize=`expr $beforeFileSize - $afterFileSize`
	ratio=$(echo "scale=2; $reduceSize*100.0/$beforeFileSize*1.0" | bc)
	if [ $reduceSize -gt 0 ]; then
		echo "reduce size->"$reduceSize 1>>$LOG_FILE
		echo "compress ratio->"$ratio"%" 1>>$LOG_FILE
		if [ $afterFileSize -eq 0 ]; then
			cp -f $backup_png $process_png
		fi
	else
		cp -f $backup_png $process_png
		echo "can not reduce->"$process_png 1>>$LOG_FILE
	fi

	#echo $(echo "scale=5; 5*1.0/6*1.0" | bc)

	echo ' ---------------- ' 1>>$LOG_FILE
}

# process_dir
compress_dir()
{
	process_dir=$1

	echo " => process dir $process_dir"

	# first backup dir
	backup_dir="`dirname $1/file`.backup"
	rm -rf $backup_dir
	mkdir $backup_dir
	(cd $process_dir && tar -cf - .) | ( cd $backup_dir && tar -xf - .)

	cd $process_dir
	for fileName in $(find -name "*.png")
	do
		process_png=$process_dir/$fileName
		backup_png=$backup_dir/$fileName
		compress_png $process_png $backup_png
	done
}

# process_png
compress_one_png()
{
	process_png=$1
	backup_png="${process_png}.backup"
	cp $process_png $backup_png

	compress_png $process_png $backup_png
}

rm -f $LOG_FILE
if [ -d "$1" ]; then
	compress_dir $1
elif [ -f "$1" ]; then
	compress_one_png $1
else
	help_cmd
	exit 1
fi
