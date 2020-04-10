#!/bin/bash

# In case of problem with TIME_WAIT connections
# echo -n 1 > /proc/sys/net/ipv4/tcp_tw_recycle

P=10
N=5

function do_job {
   echo "$(date -R): Worker $i forked..."

   if [ $(($1 % 2)) -eq 0 ]; then
     url="http://urla/"
   else 
     url="http://urlb/"
   fi

   # rendez-vous !
   read line < "$target/rdv"
   echo "$(date -R): Worker $i started on $url..."

   for ((j=0;j<N; j++)); do
     wget -q -O /dev/null -o "$2/wrk-$j.err" --server-response "$url"
   done
   echo "$(date -R): Worker $i stopping..."
}

echo "Forking $P workers..."

target="$(date "+%Y-%m-%d_%H-%M-%S")"
mkdir "$target"
mkfifo "$target/rdv"

for ((i=0;i<P; i++)); do
  mkdir -p "$target/$i"
  (do_job $i "$target/$i") > "$target/$i/out.log" 2> "$target/$i/err.log" &
done

wait_time=30
echo "Waiting $wait_time sec for all childs to initialize..."
sleep $wait_time

echo "Starting workers for $N requests..."
echo -n > "$target/rdv"

echo "Waiting for childs..."
wait 

for file in "$target"/*/wrk-*.err; do
  exec < $file
  read prot code resp
  echo $code
done | sort |uniq -c | ( sum=0; while read amount code; do 
  sum=$((sum + amount))
  echo "$code $amount"
done; echo "total $sum" )

exit 0

