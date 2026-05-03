#!/bin/sh
name="$1"
case "$name" in
    *enacast*) echo "#22c55e"; exit ;;
    *bikecrm*) echo "#f97316"; exit ;;
    *leadhunter*) echo "#3b82f6"; exit ;;
esac
palette="#3b82f6 #a855f7 #ec4899 #14b8a6 #eab308 #ef4444 #06b6d4 #6366f1"
sum=$(printf '%s' "$name" | cksum | awk '{print $1}')
n=$(echo $palette | wc -w)
idx=$((sum % n))
i=0
for c in $palette; do
    [ "$i" -eq "$idx" ] && echo "$c" && exit 0
    i=$((i+1))
done
echo "#374151"
