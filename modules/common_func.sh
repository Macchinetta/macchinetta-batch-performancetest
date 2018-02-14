#!/bin/bash - 
#=============================================================================
#
#           FILE: common_func.sh
#
#    DESCRIPTION: 共通関数モジュール
#           NOTE: 関数ヘッダの各項目は、以下の意味を持つ。
#                 USE_GLOBAL: 当該関数で使用する、condition.shにて定義されるグローバル変数
#                  PARAMETER: 当該関数の各引数の説明
#                    RETURNS: 当該関数が出力する処理結果の説明
#                            （出力しない場合は"---"）
#
# COPYRIGHT NOTE: Copyright(c) 2017 NTT Corporation.
#        CREATED: 2015年3月13日
#        UPDATED: 2017年12月18日
#        VERSION: 2.0.0
#
#============================================================================

set -o nounset                              # Treat unset variables as an error


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  get_time
#   DESCRIPTION:  システム現在日時を取得
#    PARAMETERS:  ---
#       RETURNS:  システム現在日時
#-------------------------------------------------------------------------------
get_time(){
   echo `date +"%Y/%m/%d %H:%M:%S"`
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  calc_diff_time
#   DESCRIPTION:  YYYY/MM/dd hh:mm:ss形式の時刻の差分時間を算出する
#    PARAMETER1:  時刻１（後の時間）
#    PARAMETER2:  時刻２（前の時間）
#       RETURNS:  差分時間
#-------------------------------------------------------------------------------
calc_diff_time(){
   time1=`date -d "${1}" +'%s'`
   time2=`date -d "${2}" +'%s'`
   echo `expr ${time1} - ${time2}`
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  reset_env
#   DESCRIPTION:  強制的環境の復元処理
#    PARAMETERS:  
#   USE_GLOBAL1:  DB_IPADDRESS:DBサーバのIPアドレス
#   USE_GLOBAL2:  DB_CLUSTER_LOCATION:PostgreSQL DBクラスタのディレクトリパス
#   USE_GLOBAL3:  SAR_PROCESS_INFO_BUFFER_FILE:sarプロセス情報出力ファイル名
#   USE_GLOBAL4:  ASYNC_EXECUTOR_STOP_FILE_PATH:AsyncBatchDaemonの停止ファイルパス
#   USE_GLOBAL5:  RESULT_LOCATION:測定結果のディレクトリパス（バッチサーバ）
#   USE_GLOBAL6:  TEST_EXECUTION_RESULT_DIR:性能検証プログラム実行ごとの結果格納ディレクトリ
#   USE_GLOBAL7:  RESULT_DB_LOCATION:測定結果のディレクトリパス（DBサーバ）
#   USE_GLOBAL8:  SAMPLE_AP_OUTPUT_LOCATION:サンプルアプリケーションのディレクトリパス
#   USE_GLOBAL9:  HEAPSTATS_PATH:HeapStats情報ファイル
#   USE_GLOBAL10: GC_PATH:GC情報ファイル
#   USE_GLOBAL11: ACTION_LOG_LOCATION:サンプルアプリケーション動作ログのファイルパス
#   USE_GLOBAL12: DB_SSH_PORT:DBサーバへSSH接続する際の指定ポート番号
#   USE_GLOBAL13: DB_MASTER_NAME:PostgreSQLを起動するOSユーザ名
#   USE_GLOBAL14: DB_PATH_SOURCE_FILE_PATH:PostgreSQLを起動する際にpg_ctlのパスを通すために参照するファイル
#       RETURNS:  ---
#-------------------------------------------------------------------------------
reset_env(){
   logger_debug "強制的環境の復元処理"
   ssh -p ${DB_SSH_PORT} ${DB_MASTER_NAME}@${DB_IPADDRESS} "source ${DB_PATH_SOURCE_FILE_PATH}; pg_ctl -D ${DB_CLUSTER_LOCATION} stop"
   if [ $? -ne 0 ]; then
      logger_warn "DBの停止処理に失敗しました"
   fi
   kill `cat "${RESULT_LOCATION}/${TEST_EXECUTION_RESULT_DIR}/${SAR_PROCESS_INFO_BUFFER_FILE}"`
   if [ $? -ne 0 ]; then
      logger_warn "バッチサーバにおけるsarの停止に失敗しました"
   else
      rm "${RESULT_LOCATION}/${TEST_EXECUTION_RESULT_DIR}/${SAR_PROCESS_INFO_BUFFER_FILE}"
      if [ $? -ne 0 ]; then
         logger_warn "バッチサーバにおけるsarのpidファイルの削除に失敗しました"
      fi
   fi
   ssh -p ${DB_SSH_PORT} ${DB_MASTER_NAME}@${DB_IPADDRESS} "kill \`cat \"${RESULT_DB_LOCATION}/${TEST_EXECUTION_RESULT_DIR}/${SAR_PROCESS_INFO_BUFFER_FILE}\"\`"
   if [ $? -ne 0 ]; then
      logger_warn "DBサーバにおけるsarの停止に失敗しました"
   else
      ssh -p ${DB_SSH_PORT} ${DB_MASTER_NAME}@${DB_IPADDRESS} "rm \"${RESULT_DB_LOCATION}/${TEST_EXECUTION_RESULT_DIR}/${SAR_PROCESS_INFO_BUFFER_FILE}\""
      if [ $? -ne 0 ]; then
         logger_warn "DBサーバにおけるsarのpidファイルの削除に失敗しました"
      fi
   fi
   rm ${ASYNC_EXECUTOR_STOP_FILE_PATH}
   if [ $? -ne 0 ]; then
      logger_warn "AsyncBatchDaemonの停止ファイルの削除に失敗しました"
   fi
   rm ${SAMPLE_AP_OUTPUT_LOCATION}/*
   if [ $? -ne 0 ]; then
      logger_warn "バッチ結果出力の削除に失敗しました"
   fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  end_if_error
#   DESCRIPTION:  エラー終了関数
#    PARAMETER1:  確認対象コマンド戻り値（0以外なら、異常終了する）
#    PARAMETER2:  エラーメッセージ 
#       RETURNS:  ---
#-------------------------------------------------------------------------------
end_if_error(){
   if [ ${1} -ne "0" ]; then
      logger_error "${2}"
      reset_env
      kill $$
   fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  end_if_warn
#   DESCRIPTION:  WARNログ出力関数
#    PARAMETER1:  確認対象コマンド戻り値（0以外なら、ログを出力する）
#    PARAMETER2:  WARNメッセージ 
#       RETURNS:  ---
#-------------------------------------------------------------------------------
end_if_warn(){
   if [ ${1} -ne "0" ]; then
      logger_warn "${2}"
   fi
}
