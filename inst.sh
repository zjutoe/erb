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
	#echo -n $ln
	pc=$(cut -f1 -d':' <<< $ln)
	inst=$(cut -f2 -d':' <<< $ln)
	read -r op para <<< $inst

	case $op in
	    'lb' | 'lbu' | 'lh' | 'lhu' | 'll' | 'lw' | 'lwl' | 'lwr' | \
	    'sb' | 'sbu' | 'sh' | 'shu' | 'ss' | 'sw' | 'sws' | 'swr' )
		#rt=$(cut -f1 -d','<<< $para)
		rst=$(cut -f2 -d','<<< $para)
		offset=$(cut -f1 -d'(' <<< $rst)
		rst=$(cut -f2 -d'(' <<< $rst)
		base=$(cut -f1 -d')' <<< $rst)
		echo "$pc: $offset + 0x${gpr[$base]}"
		;;
	    # 'nop')
	    # 	echo ""
	    # 	;;
	    # *)
	    # 	IFS=, read -r rs rt rd <<< $para
	    # 	echo -n ' :'
	    # 	if [ -n "$rs" ]; then 
	    # 	    echo " $rs" 
	    # 	fi
	    # 	if [ -n "$rt" ]; then 
	    # 	    echo " $rt" 
	    # 	fi
	    # 	if [ -n "$rd" ]; then 
	    # 	    echo " $rd" 
	    # 	fi
	esac	
    fi
done
