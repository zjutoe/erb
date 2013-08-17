#!/bin/bash
flog=$1

declare -A gpr=()
gpr['zero']=0

grep -v -e ^f -e '^ ' -e '^CP' -e ^IN: -e ^OP -e ^pc= $flog | while read -r ln; do
    if [[ $ln = GPR* ]]; then
	read -r m r1 v1 r2 v2 r3 v3 r4 v4 <<< $ln
	gpr[$r1]=$v1
	gpr[$r2]=$v2
	gpr[$r3]=$v3
	gpr[$r4]=$v4
    fi
    if [[ $ln = 0x* ]]; then
	echo $ln
	inst=$(cut -f2 -d':' <<< $ln)
	read -r op para <<< $inst
	echo op $op
	echo para $para
	
	#echo $inst #$addr
	#sed 's/,/:/g' <<< $ln | read -r addr op rs rt rd
	#echo $op $rs $rt $rd
	#echo ${gpr[$rs]} 
#${gpr[$rt]} #${gpr[$rd]}
    fi
done
