#!/bin/bash

while getopts "hvp:" option; do
	case ${option} in 
		h)
			echo "Give image to draw as first argument of the script"; exit 0 ;;
		v)
			echo "1.0" ; exit 0 ;;
	esac
done

START=$(date +%s)

IMG=$1

if [[ ! -f $IMG ]] ; then
	echo "Given file does not exist"
	exit 0
fi

MCOLS=$(tput cols)
MLINES=$(tput lines)
MLINES=$(( $MLINES - 1 )) # -1 due to input line
IMG_W=$MCOLS
IMG_H=$MLINES

COMP_IMG=$(mktemp)
COMPRESS_COMMAND="convert $IMG -resize "$IMG_W"x"$IMG_H"\! $COMP_IMG"
eval $COMPRESS_COMMAND 

declare -a R_VAL
declare -a G_VAL
declare -a B_VAL

#Some versions of image magick require space in command, others not
CONDITIONAL_SPACE_IN_COMMAND=""

assign_space_if_needed () {
	ERROR_STATEMENT="unable to open"
	TEST_COMMAND="convert "$COMP_IMG"[:] txt:"
	if eval $TEST_COMMAND | grep -q $ERROR_STATEMENT; then
		CONDITIONAL_SPACE_IN_COMMAND=" "
	fi
}

assign_space_if_needed

list_pixels_hex () {
	LIST_COMMAND="convert ${COMP_IMG}${CONDITIONAL_SPACE_IN_COMMAND}[:] txt: | tail -n +2 | cut -d \" \" -f \"1,4\" | sed -e 's/://g' -e 's/#//g' -e 's/://g' -e 's/,/ /g'"
	eval $LIST_COMMAND
}

load_pixels () {
	ITER=0
	TOTAL_TILES=$(( $IMG_W * $IMG_H  ))
	UPDATE_THRESHOLD=10
	while read LINE ; do
		REMAINDER=$(( $ITER % $UPDATE_THRESHOLD ))
		if [[ $REMAINDER -eq 0 ]]; 
		then
			clear
			PROGRESS=$(( 100 * $ITER / $TOTAL_TILES ))
			CURR_TIME=$(date +%s)
			TIME=$(( $CURR_TIME - $START  ))
			echo "Progress: $PROGRESS%, total time: $TIME s."
		fi
    		
		read X Y HEX <<< $LINE
		#echo "$X | $Y | $HEX"
		COL=$X
		LINE=$Y
		INDEX=$(( $MCOLS * $LINE + $COL ))
		
		#calculate RGB
		A=`echo $HEX | cut -c-2`
		B=`echo $HEX | cut -c3-4`
		C=`echo $HEX | cut -c5-6`
		R=`echo "ibase=16; $A" | bc`
		G=`echo "ibase=16; $B" | bc`
		B=`echo "ibase=16; $C" | bc`
		#echo $X $Y $R $G $B
		
		R_VAL[$INDEX]=$R
		G_VAL[$INDEX]=$G
		B_VAL[$INDEX]=$B
		
		ITER=$(( $ITER + 1 )) 
	done < <( list_pixels_hex)
}


echo_tile_of_color () {
	R=$1
	G=$2
	B=$3
	PRINT_COMMAND="echo -n -e \"\033[38;2;"$R";"$G";"$B"m█\033[0;00m\""
	eval $PRINT_COMMAND
}

print_tiles () {
	for (( Y=0; Y<$MLINES; Y++ ))
	do
		for (( X=0; X<$MCOLS; X++ ))
		do
			INDEX=$(( $MCOLS * $Y + $X ))
			#echo $INDEX
			R=${R_VAL[$INDEX]}
			G=${G_VAL[$INDEX]}
			B=${B_VAL[$INDEX]}
			#echo RGB: $R $G $B
			echo_tile_of_color $R $G $B
		done
	done
}

load_pixels
print_tiles
