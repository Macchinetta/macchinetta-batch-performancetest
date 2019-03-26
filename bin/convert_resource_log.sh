#!/bin/bash -
#=============================================================================
#
#           FILE: convert_resource_log.sh
#
#          USAGE: bash convert_resource_log.sh SOURCE DEST_NAME
#
#    DESCRIPTION: 「検証条件取得機能」実行ファイル.
#                 サーバリソース情報ファイルSOURCE(sar出力結果)から情報を抽出し、シェル実行ディレクトリにDEST_NAMEのサーバリソース情報抽出ファイルを出力する
#
# COPYRIGHT NOTE: Copyright(c) 2017 NTT Corporation.
#        CREATED: 2015年3月13日
#        UPDATED: 2017年12月18日
#        VERSION: 2.1.1
#
#============================================================================

set -o nounset                              # Treat unset variables as an error

prefix="/tmp/${2}_sar_buf"

ret_id=0

# メモリ情報の抽出
sar -f ${1} -r | grep "時" | awk '{print $2","$3","$5","$6}' > ${prefix}_r.dat
ret_id=${PIPESTATUS[0]}
# CPU情報の抽出(1行目のヘッダでは、1列目の時刻を文字列"時刻"に変換して出力する)
sar -f ${1} -u | grep "時" | awk '{if(NR==1){print "時刻,"$3","$5","$6","$8}else{print $1","$3","$5","$6","$8}}' > ${prefix}_u.dat
ret_id=${PIPESTATUS[0]}
# ディスクIO情報の抽出
sar -f ${1} -b | grep "時" | awk '{print $2","$3","$4","$5","$6}' > ${prefix}_b.dat
ret_id=${PIPESTATUS[0]}
# ネットワークIO情報の抽出（すべてのネットワークデバイスの値の合算値を算出する）
sar -f ${1} -n DEV | grep "時" | awk '{if(t==0){t=$1;a3=$3;a4=$4;a5=$5;a6=$6;a7=$7;a8=$8;a9=$9}else if(t==$1){a3+=$3;a4+=$4;a5+=$5;a6+=$6;a7+=$7;a8+=$8;a9+=$9}else{print a3","a4","a5","a6","a7","a8","a9;t=$1;a3=$3;a4=$4;a5=$5;a6=$6;a7=$7;a8=$8;a9=$9}}END{print a3","a4","a5","a6","a7","a8","a9}' > ${prefix}_nDEV.dat
ret_id=${PIPESTATUS[0]}

if [ ${ret_id} -eq 0 ]; then
   # 抽出情報のまとめ
   paste -d"," ${prefix}_u.dat ${prefix}_r.dat ${prefix}_nDEV.dat ${prefix}_b.dat > ./${2}
fi
# 一時ファイルの削除
rm ${prefix}_*.dat

