#!/bin/bash

# export env variables
source env.sh

# store result
rm -rf result.csv
echo "M/K/N,avg_tflops,avg_gbs,max_tflops,max_gbs,min_tflops,min_gbs" | tee result.csv
# 24 -->4096
# 56 -->8192
for ((i=24; i<=24; i++))
do
    shape_size=$((1024 + 128 * $i))
    echo "shape size: $shape_size"
    
    rm -rf log.txt

    # update shape size in driver.py and 09-experimental-block-pointer.py
    sed -i "s/for i in \[[0-9]*\]\]/for i in \[$i\]\]/g" 09-experimental-block-pointer.py
    sed -i "s/128 \* [0-9]*;/128 \* $i;/g" ../../third_party/intel/backend/driver.py


    python 09-experimental-block-pointer.py 2>&1 | tee log.txt

    rm -rf result.csv log.txt && python 09-experimental-block-pointer.py 2>&1 | tee log.txt

    Triton_tflops_max=`grep "Triton Peak TFlops" log.txt | awk '{print $NF}' | awk 'BEGIN{max=0} {if ($1>max) max=$1} END{print max}'`
    Triton_tflops_min=`grep "Triton Peak TFlops" log.txt | awk '{print $NF}' | awk 'BEGIN{min=9999} {if ($1<min) min=$1} END{print min}'`
    Triton_tflops_avg=$(grep "Triton Peak TFlops" log.txt | awk '{print $NF}' | awk -v max="$Triton_max" -v min="$Triton_min" '{sum+=$1} END{print (sum-max-min)/NR}')

    Triton_gbs_max=`grep "Triton Peak HBM" log.txt | awk '{print $NF}' | awk 'BEGIN{max=0} {if ($1>max) max=$1} END{print max}'`
    Triton_gbs_min=`grep "Triton Peak HBM" log.txt | awk '{print $NF}' | awk 'BEGIN{min=9999} {if ($1<min) min=$1} END{print min}'`
    Triton_gbs_avg=$(grep "Triton Peak HBM" log.txt | awk '{print $NF}' | awk -v max="$Triton_gbs_max" -v min="$Triton_gbs_min" '{sum+=$1} END{print (sum-max-min)/NR}')    

    echo $Triton_tflops_avg,$Triton_gbs_avg,$Triton_tflops_max,$Triton_gbs_max,$Triton_tflops_min,$Triton_gbs_min | tee -a result.csv
done

cat result.csv