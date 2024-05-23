#!/bin/sh

PORT=$1
USER=$2
PASS=$3
file=$4
g=$5
LOGF=`basename $0`.log

if [ -z "$PORT" -o -z "$USER" -o -z "$PASS" -o -z "$file" -o -z "$g" ]
then
  echo "Usage: `basename $0` [DSN] [user] [password] [ttl-file] [graph-iri]"
  exit
fi

if [ ! -f "$file" -a ! -d "$file" ]
then
    echo "$file does not exists"
    exit 1
fi

mkdir READY 2>/dev/null
rm -f $LOGF $LOGF.*

echo "Starting..."
echo "Logging into: $LOGF"

DOSQL ()
{
    isql $PORT $USER $PASS verbose=on banner=off prompt=off echo=ON errors=stdout exec="$1" > $LOGF
}

LOAD_FILE ()
{
    f=$1
    g=$2
    echo "Loading $f (`cat $f | wc -l` lines) `date \"+%H:%M:%S\"`" | tee -a $LOG

    DOSQL "ttlp_mt (file_to_string_output ('$f'), '', '$g', 17); checkpoint;" > $LOGF

    if [ $? != 0 ]
    then
        echo "An error occurred, please check $LOGF"
        exit 1
    fi

    echo `cat ${LOGF}`
    line_no=`grep Error $LOGF | awk '{ match ($0, /line [0-9]+/, x) ; match (x[0], /[0-9]+/, y); print y[0] }'`
    newf=$f.part
    inx=1
    while [ ! -z "$line_no" ]
    do
        echo "awk and BEGIN ${line_no}"
        cat $f |  awk "BEGIN { i = 1 } { if (i==$line_no) { print \$0; exit; } i = i + 1 }"  >> bad.nt
        line_no=`expr $line_no + 1`
        echo "Retrying from line $line_no"
        echo "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ." > tmp.nt
        cat $f |  awk "BEGIN { i = 1 } { if (i>=$line_no) print \$0; i = i + 1 }"  >> tmp.nt
        mv tmp.nt $newf
        f=$newf
        mv $LOGF $LOGF.$inx
        DOSQL "ttlp_mt (file_to_string_output ('$f'), '', '$g', 17); checkpoint;" > $LOGF

        if [ $? != 0 ]
        then
            echo "An error occurred, please check $LOGF"
            exit 1
        fi
        line_no=`grep Error $LOGF | awk '{ match ($0, /line [0-9]+/, x) ; match (x[0], /[0-9]+/, y); print y[0] }'`
        inx=`expr $inx + 1`
    done
    rm -f $newf 2>/dev/null
    echo "Loaded.  "
}

echo "======================================="
echo "Loading started."
echo "======================================="

if [ -f "$file" ]
then
    LOAD_FILE $file $g
    mv $file READY 2>> /dev/null
elif [ -d "$file" ]
then
    ###
    # CHANGE file name for your enviroment
    ###
    #for ff in `find $file -name '*.nt'`
    for ff in `find $file -name '*.ttl'`
    do
        LOAD_FILE $ff $g
        mv $ff READY 2>> /dev/null
    done
else
   echo "The input is not file or directory"
fi
echo "======================================="
echo "Final checkpoint."
DOSQL "checkpoint;" > temp.res
echo "======================================="
echo "Check bad.nt file for skipped triples."
echo "======================================="

exit 0
