hosts="$(/usr/bin/getent hosts)"


IFS=$'\n' lines=($hosts)
count=0
while [ "x${lines[count]}" != "x" ]
do
	line=${lines[count]}
	IFS=$' ' words=($line)

	host_names[count]=${words[1]}.conf

	count=$(( $count + 1 ))
done

array=$( ls /etc/apache2/sites-enabled )


IFS=$'\n' lines=($array)
count=0
while [ "x${lines[count]}" != "x" ]
do

	if [[ ! " ${host_names[*]} " == *"${lines[count]}"* ]]; then
	    /usr/bin/sudo rm /etc/apache2/sites-enabled/${lines[count]}
	fi

	count=$(( $count + 1 ))
done
