#!/bin/bash - 
#=============================================================================
#
#           FILE: job_func.sh
#
#    DESCRIPTION: 「検証実行機能」の「サンプルアプリケーションの実行機能」用関数モジュール
#           NOTE: 関数ヘッダの各項目は、以下の意味を持つ。
#                 USE_GLOBAL: 当該関数で使用する、condition.shにて定義されるグローバル変数
#                  PARAMETER: 当該関数の各引数の説明
#                    RETURNS: 当該関数が出力する処理結果の説明
#                            （出力しない場合は"---"）
#
# COPYRIGHT NOTE: Copyright(c) 2017 NTT Corporation.
#        CREATED: 2015年3月13日
#        UPDATED: 2017年12月18日
#        VERSION: 2.1.1
#
#============================================================================

set -o nounset                              # Treat unset variables as an error

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  wait_async_job_end
#   DESCRIPTION:  非同期型ジョブの終了待ち
#   USE_GLOBAL1:  DB_PSQL_PORT:DBサーバへpsql接続する際の指定ポート番号
#   USE_GLOBAL2:  DB_DATABASE_NAME:検証データ格納するDBのデータベース名
#   USE_GLOBAL3:  DB_USER_NAME:検証データ格納するDBのユーザ名
#   USE_GLOBAL4:  ASYNC_EXECUTE_JOB_NUM_SQL:実行中非同期型ジョブ数の取得SQL文
#   USE_GLOBAL5:  DB_IPADDRESS:DBサーバのIPアドレス
#       RETURNS:  --- 
#-------------------------------------------------------------------------------
wait_async_job_end(){
   logger_debug "非同期型ジョブの終了待ち"
   while [ 1 ]
   do
      logger_debug "非同期型ジョブの終了待機中"
      job_count=`psql -h ${DB_IPADDRESS} -p ${DB_PSQL_PORT} -d ${DB_DATABASE_NAME} -U ${DB_USER_NAME} -At -c "${ASYNC_EXECUTE_JOB_NUM_SQL}"`
      if [ ${job_count} -eq 0 ]; then
         logger_debug "すべての非同期型ジョブの終了を確認"
         return 0
      fi
      sleep 1
   done
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  get_end_time
#   DESCRIPTION:  非同期型ジョブの終了した日時をサンプルアプリケーションの動作ログから取得
#    PARAMETER1:  実行中非同期型ジョブ数の取得SQL文
#   USE_GLOBAL1:  DB_PSQL_PORT:DBサーバへpsql接続する際の指定ポート番号
#   USE_GLOBAL2:  DB_DATABASE_NAME:検証データ格納するDBのデータベース名
#   USE_GLOBAL3:  DB_USER_NAME:検証データ格納するDBのユーザ名
#   USE_GLOBAL4:  DB_IPADDRESS:DBサーバのIPアドレス
#       RETURNS:  非同期型ジョブの停止判定ログプレフィックスに合致するログの、ログ出力時間
#-------------------------------------------------------------------------------
get_end_time(){
   endtime=`psql -h ${DB_IPADDRESS} -p ${DB_PSQL_PORT} -d ${DB_DATABASE_NAME} -U ${DB_USER_NAME} -At -c "${1}"`
   echo ${endtime}
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  get_no_data_total_num
#   DESCRIPTION:  集計対象ファイルにおけるジョブが処理したデータ件数以外の行数を取得する(各ファイルのTEST_COLLECT_TARGET_NO_DATA_LINEの行数の総和)
#    PARAMETER1:  集計対象ファイルのデータ部以外行数
#   USE_GLOBAL1:  SAMPLE_AP_OUTPUT_LOCATION:バッチ結果出力パス
#       RETURNS:  集計対象ファイルにおけるジョブが処理したデータ件数以外の行数
#-------------------------------------------------------------------------------
get_no_data_total_num(){
   file_count=`ls ${SAMPLE_AP_OUTPUT_LOCATION} | wc -l`
   echo `expr ${file_count} \* ${1}`
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  get_data_num
#   DESCRIPTION:  ジョブが処理したデータ件数を取得する(行数からデータ部以外の行数を引き算)
#    PARAMETER1:  集計対象ファイル
#    PARAMETER2:  データ部以外の行数
#       RETURNS:  ジョブが処理したデータ件数
#-------------------------------------------------------------------------------
get_data_num(){
   total_num=`cat ${1} | wc -l`
   echo `expr ${total_num} - ${2}`
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  calc_throughput
#   DESCRIPTION:  スループットを計算する
#    PARAMETER1:  DATA_NUM
#    PARAMETER2:  DIFF_TIME
#       RETURNS:  スループット（DIFF_TIMEが0ならNANを返す）
#-------------------------------------------------------------------------------
calc_throughput(){
   if [ ${2} -gt 0 ]; then
      echo `expr ${1} / ${2}` # スループットの取得(有効数字に注意)
   else
      echo "NAN" # DIFF_TIMEが0なら、NANを返す
   fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  export_job_log
#   DESCRIPTION:  検証結果ファイルの出力
#    PARAMETER1:  ジョブNo.
#    PARAMETER2:  データ件数 
#    PARAMETER3:  試行回数 
#    PARAMETER4:  バッチ開始時刻 
#    PARAMETER5:  バッチ終了時刻 
#    PARAMETER6:  応答時間（ターンアラウンドタイム） 
#    PARAMETER7:  スループット 
#    PARAMETER8:  検証結果ファイルの格納ディレクトリ
#   USE_GLOBAL1:  PERFORMANCE_RESULT_LOG:検証結果ファイル名 
#       RETURNS:  --- 
#-------------------------------------------------------------------------------
export_job_log(){
   logger_info "検証結果ファイルの出力"
   logger_info "ジョブNo.:                          ${1}"
   logger_info "データ件数:                         ${2}"
   logger_info "試行回数:                           ${3}"
   logger_info "バッチ開始時刻:                     ${4}"
   logger_info "バッチ終了時刻:                     ${5}"
   logger_info "応答時間（ターンアラウンドタイム）: ${6}"
   logger_info "スループット:                       ${7}"
   logger_info "検証結果ファイルの格納ディレクトリ: ${8}"
   logger_info "検証結果ファイル名:         ${PERFORMANCE_RESULT_LOG}"
   echo "${1},${2},${3},${4},${5},${6},${7}" >> "${8}/${PERFORMANCE_RESULT_LOG}"
   end_if_error $? "検証結果ファイルの出力に失敗しました"
}

