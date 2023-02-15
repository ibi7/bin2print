#!/usr/bin/env bash
# vim: ft=bash tw=78 ts=2 sw=2 sts=2 sr noet

##      AUTHOR: EUDOYS ibi7
##     VERSION: 0.0.1-alpha
##    DATETIME: 2023-02-15 22:50
## DESCRIPTION: Implement basic encode functions.

## ----- CONFIGURATION AREA START -----
GS_PATH=""
QRENCODE_PATH="$(dirname -- $0)/bin"
ZBAR_PATH=""
## ----- CONFIGURATION AREA END -----

## ----- include PATH variable -----
for depends in GS_PATH ZBAR_PATH QRENCODE_PATH; do
  [[ -d "${!depends}" ]] && PATH="${!depends}:$PATH"
done; export PATH

## ----- dependencies ckeck -----
for depends in split base64 awk qrencode; do
  hash $depends 2>/dev/null ||
  { echo "ERROR: Unsatisfied dependencies, missing $depends"; exit 1; }
done

if hash gswin64c 2>/dev/null; then
  GS_EXEC=gswin64c.exe
elif hash gs 2>/dev/null; then
  GS_EXEC=gs
else
  echo "ERROR: Unsatisfied dependencies, missing Ghostscript"
  exit 1
fi

## ----- info calculation -----
FN="$1"
FILESIZE=$(stat -c'%s' "$FN")
FILESHA1="$(sha1sum $FN | cut -d' ' -f1)"
LAYOUT='4x6'
SIZEPERQR=$((2*2**10))
SIZEPERPAGE=$((${LAYOUT/x/*}*SIZEPERQR))
BLKCOUNT=$(((FILESIZE+SIZEPERQR-1)/SIZEPERQR))
PAGECOUNT=$(((FILESIZE+SIZEPERPAGE-1)/SIZEPERPAGE))
export BLKCOUNT

## Head1: data processing by bash for PostScr
export H1=$(cat << EOH
%!PS
30000000 setvmthreshold  %% to accelerate CJK font processing
/! {bind def} bind def
/# {load def}!
/FD {findfont exch scalefont setfont}!
/F1 {/Courier-Bold FD}!
%% add the following line into '${GS_PATH}/lib/cidfmap' to define the font ttf you want,
%% spaces and semicolons at the end of lines are required!
%% /FontAlias << /Path (FontPath/FontFileName.ttf) /FileType /TrueType /CSI [(GB1) 2] /SubfontID 0 >> ;
%% Here /FontAlias is /XingShu in my computer
/F2 {/XingShu-UniGB-UTF8-H FD}!
/matrixLayoutH ${LAYOUT%%x*} def /matrixLayoutV ${LAYOUT##*x} def
/FNAME ($(basename $FN)) def
/FINFO (  SHA1: ${FILESHA1}  Size: ${FILESIZE}  TotalBlocks: ${BLKCOUNT}) def
/pc ($PAGECOUNT) def  %% total page count number
/blkcount ${#BLKCOUNT} def
EOH
)
## Head2: data and function define in PostScr
export H2=$(cat << 'EOH'
/A /setgray #
/D /rlineto #
/F /fill #
/G /rmoveto #
/I /index #
/J /scale #
/L /lineto #
/M /moveto #
/N /newpath #
/P /closepath #
/R /rotate #
/S /stroke #
/T /translate #
/U /grestore #
/V /gsave #
/W /setlinewidth #
/Z /show #
/ppi 72 def /inch {ppi mul}! /mm {inch 25.4 div}!
/a4H 210 mm def            /a4V 297 mm def
<< /PageSize [a4H a4V] /Orientation 0 >> setpagedevice
/tlFH 5 mm def  %% title line font height
/snFH 3 mm def  %% serial number font height
/qrDPI 100 def             /qrSize 173 qrDPI div inch def
/matrixSepH 4 mm def       /matrixSepV 2 mm def
/matrixWidth qrSize matrixSepH add matrixLayoutH mul def
/matrixHeight matrixLayoutV qrSize mul matrixSepV matrixLayoutV 1 sub mul add def
/mar 5 mm def  %% page round rectangle box margin
/matrixBottom mar 2 mm add def
/matrixTop matrixBottom matrixHeight add def
/matrixLeft a4H matrixWidth sub 2 div def
/blk 0 def                 /blkInc {/blk blk 1 add def}!
/blkPerPage matrixLayoutH matrixLayoutV mul def
/concatstrings {  %% (A) (B) --> (AB)
  exch dup length 2 index length add string
  dup dup 4 2 roll copy length 4 -1 roll putinterval
}!
/n2s {16 string cvs}!
/n2s0p {  %% num pad_length --> str
  dup dup 4 -2 roll 10 exch exp cvi add exch
  1 add string cvs exch 1 exch getinterval
}!
/pos {  %% blk_num --> posX posY
  dup 1 sub matrixLayoutH mod qrSize matrixSepH
  add mul matrixLeft add matrixSepH add
  exch 1 sub matrixLayoutH div floor cvi
  matrixLayoutV mod qrSize matrixSepV add mul
  matrixTop exch sub qrSize sub
}!
%% page number: blk -->
/pn {blkPerPage div ceiling cvi}!
%% progress bar of blocks: blk --> blk
/blkpb {dup n2s print ( ) print}!
%% progress bar of new pages, call after showpage
/pagepb {(\nPage) blk 1 add pn n2s (: ) 2 {concatstrings} repeat print} def
/pop4 {pop pop pop pop}!
%% draw round rectangle box around page
/box { %% llx lly urx ury r -->
  V 0 A 0.38 mm W N dup 3 I exch sub 2 I M
  2 I 2 I 1 I 6 I 4 I arcto pop4 2 I 4 I 2 I add L
  2 I 4 I 6 I 1 I 4 I arcto pop4 4 I 1 I add 4 I L
  4 I 4 I 1 I 4 I 4 I arcto pop4 4 I 2 I 2 I sub L
  4 I 2 I 4 I 1 I 4 I arcto pop4 P S U
}!
%% a blank paper makes you to find easier
%% you can manually design a real cover later
/drawCover {(Blank Paper First:) print showpage pagepb} def
/drawPageAround {
  V 15 mm matrixTop 2 mm add T 0 0 M snFH F1
    (Page [) blk pn n2s (/) pc (]) FINFO 5 {concatstrings} repeat show U
  V 15 mm matrixTop 3 mm add snFH add T 0 0 M tlFH F2 FNAME show U
  mar dup a4H mar sub a4V mar sub mar box
} def
/p {M 0 1 D 1 0 D 0 -1 D F}!  %% draw point
/pre {V blkInc blk blkpb pos T ppi qrDPI div dup J 0 A} def
/post {
  U V blk pos M -2.5 mm 25 mm G -90 R snFH F1 blk blkcount n2s0p show U
  blk blkPerPage mod 0 eq { drawPageAround showpage pagepb } if
} def
EOH
)
## ----- MAIN LOGIC -----
split -b2k --suffix-length=${#BLKCOUNT} \
  --numeric-suffixes=1 --filter='
    (printf "<%0${#BLKCOUNT}d>" $((10#$FILE)); base64 -w0) |
    qrencode -o- -s1 -m0 -lL -v39 --strict-version -tEPS' \
  - "" < <(cat -- "${1:--}") |
awk -v h1="${H1}" -v h2="${H2}" \
  'BEGIN {
    print h1; print h2; print "drawCover";
  } NR%14==13 {
    print "pre", $0, "post"
  } END {
    print "blk blkPerPage mod 0 ne { drawPageAround showpage } if"
  }' |
"${GS_EXEC}" -q -o "${1}.pdf" -sDEVICE=pdfwrite -dCompatibilityLevel=1.7 -
