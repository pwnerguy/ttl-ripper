#!/bin/bash

# TTL Ripper v0.1 
# by pwnerguy (https://github.com/pwnerguy/ttl-ripper)

# Colours

greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

# ctrl+c

function ctrl_c () {

  echo -e "\n\n${redColour}[!] Exiting...${endColour}\n"
  exit 1

}

tput civis
trap 'tput cnorm' EXIT
trap ctrl_c INT


function help () {

  echo -e "${greenColour} ______   ______   __            ______    __    ______   ______   ______    ______    ${endColour}"
  echo -e "${greenColour}/\__  _\ /\__  _\ /\ \          /\  == \  /\ \  /\  == \ /\  == \ /\  ___\  /\  == \   ${endColour}"
  echo -e "${greenColour}\/_/\ \/ \/_/\ \/ \ \ \____     \ \  __<  \ \ \ \ \  _-/ \ \  _-/ \ \  __\  \ \  __<   ${endColour}"
  echo -e "${greenColour}   \ \_\    \ \_\  \ \_____\     \ \_\ \_\ \ \_\ \ \_\    \ \_\    \ \_____\ \ \_\ \_\ ${endColour}"
  echo -e "${greenColour}    \/_/     \/_/   \/_____/      \/_/ /_/  \/_/  \/_/     \/_/     \/_____/  \/_/ /_/ ${endColour}v0.1"

  echo -e "\nby pwnerguy (https://github.com/pwnerguy/ttl-ripper)"

  echo -e "\nUsage: ./ttl-ripper.sh [options]\n"
  echo -e "  ${greenColour}-i${endColour} <ip>    TTL scan a single IP address."
  echo -e "  ${greenColour}-l${endColour} <list>  TTL scan a list of IP addresses."
  echo -e "  ${greenColour}-e${endColour} <file>  Export terminal output to a file."
  echo -e "  ${greenColour}-f${endColour}         Fast mode. 1 ICMP packet instead of 2."
  echo -e "  ${greenColour}-u${endColour}         Ultrafast mode. 1 ICMP packet + no TCP fallback in case of ICMP fail."
  echo -e "  ${greenColour}-h${endColour}         Display this help panel.\n"

}

function scan_header () {

  export_file="$1"
  fast_mode="$2"
  ultra_fast_mode="$3"

  echo -e "${greenColour} ______   ______   __            ______    __    ______   ______   ______    ______    ${endColour}"
  echo -e "${greenColour}/\__  _\ /\__  _\ /\ \          /\  == \  /\ \  /\  == \ /\  == \ /\  ___\  /\  == \   ${endColour}"
  echo -e "${greenColour}\/_/\ \/ \/_/\ \/ \ \ \____     \ \  __<  \ \ \ \ \  _-/ \ \  _-/ \ \  __\  \ \  __<   ${endColour}"
  echo -e "${greenColour}   \ \_\    \ \_\  \ \_____\     \ \_\ \_\ \ \_\ \ \_\    \ \_\    \ \_____\ \ \_\ \_\ ${endColour}"
  echo -e "${greenColour}    \/_/     \/_/   \/_____/      \/_/ /_/  \/_/  \/_/     \/_/     \/_____/  \/_/ /_/ ${endColour}v0.1"

  echo -e "\nby pwnerguy (https://github.com/pwnerguy/ttl-ripper)"

  header=$(echo -e "Started TTL Ripper v0.1 at $(date "+%Y-%m-%d %H:%M %z")")
  echo -e "\n$header"

  if [ -n "$export_file" ]; then
    echo "$header" > "$export_file"
  fi

  if [ "$fast_mode" == "1" ]; then
    echo -e "Fast mode enabled."
  elif [ "$ultra_fast_mode" == "1" ]; then
    echo -e "Ultrafast mode enabled."
  fi

}

function scan () {

  list="$1"
  export_file="$2"
  fast_mode="$3"
  ultra_fast_mode="$4"

  # Read the list line by line looping the calling to the scan function to perform all scans

  if [ -f "$list" ]; then
    while read -r line; do
      for ip in $line; do
        scan "$ip" "$export_file" "$fast_mode" "$ultra_fast_mode"
      done
    done < "$list"
    return
  fi

  # Fast/ultrafast mode

  if [ "$ultra_fast_mode" == "1" ]; then
    tries=1
  elif [ "$fast_mode" == "1" ]; then
    tries=1
  else
    tries=2
  fi

  # Extract values from ping output and analyze it

  ip="$list"

  ping_output=$(timeout 3 ping -c "$tries" -s 20 "$ip" 2>/dev/null) 
  ttl=$(echo "$ping_output" | grep -o "ttl=[0-9]*" | head -n 1 | cut -d= -f2)
  rtime=$(echo "$ping_output" | grep -o "time=[0-9.]*" | head -n 1 | cut -d "=" -f2)

  if [ -z "$ttl" ]; then

    # Ultrafast mode disables TCP fallback detection in case of not receiving any ICMP packets

    if [ "$ultra_fast_mode" == "1" ]; then
      echo -e "${redColour}[!]${endColour} '$ip' no ICMP response (ultrafast mode enabled, skipping TCP fallback...)"
      return
    fi

    echo -e "${redColour}[!]${endColour} '$ip' no ICMP response. Trying TCP fallback..."

    for port in 21 22 23 25 53 67 68 69 80 110 111 123 135 137 138 139 143 161 162 179 389 443 445 514 515 587 631 993 995 3306; do
      ( timeout 1 bash -c "echo > /dev/tcp/$ip/$port" 2>/dev/null || nc -z -w1 "$ip" "$port" >/dev/null 2>&1 ) && echo " • $ip is up via $port/tcp" &
    done; wait
    return 
  fi

  if [ $ttl -le 64 ]; then
    os="Linux / Unix (default 64)"
    hop_count=$((64-$ttl))
  elif [ $ttl -le 128 ]; then
    os="Windows (default 128)"
    hop_count=$((128-$ttl))
  elif [ $ttl -le 255 ]; then
    os="BSD / Solaris / Network devices / Other"
    hop_count=$((255-$ttl))
  else
    os="Unknown"
  fi

  # Results and file export

  output=$(
  echo -e "${yellowColour}[+]${endColour} $ip" 
  echo -e " |  TTL: $ttl"
  echo -e " |  Response time: $rtime ms"
  echo -e " |  Estimated hop count: $hop_count"
  echo -e " |_ Likely OS: $os")
 
  echo "$output"

  if [ -n "$file" ]; then
    echo "$output" >> "$file"
  fi

}

# Parameters and options

declare -i parameter_counter=0
output_file=""
fast=0
ultra_fast=0

while getopts "i:l:e:fuh" arg; do
  case $arg in
    i) ip="$OPTARG"; let parameter_counter+=1;;
    l) li="$OPTARG"; let parameter_counter+=2;;
    e) export="$OPTARG";;
    f) fast=1;;
    u) ultra_fast=1;;
    h) ;;
  esac
done

if [ $parameter_counter -eq 1 ]; then
  scan_header "$export" "$fast" "$ultra_fast"

  if ! echo "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    echo -e "${redColour}[!]${endColour} Invalid IP address '$ip'"
    exit
  fi

  scan "$ip" "$export" "$fast" "$ultra_fast"
elif [ $parameter_counter -eq 2 ]; then

  if [ ! -f "$li" ]; then
    echo -e "${redColour}[!]${endColour} List file '$li' not found.\n"
    exit 1
  fi

  scan_header "$export" "$fast" "$ultra_fast"
  scan "$li" "$export" "$fast" "$ultra_fast"
else
  help
fi
