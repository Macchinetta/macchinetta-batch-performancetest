#!/bin/bash - 
#=============================================================================
#
#           FILE: collect_func.sh
#
#    DESCRIPTION: 「検証結果収集機能」用関数モジュール
#           NOTE: 関数ヘッダの各項目は、以下の意味を持つ。
#                 USE_GLOBAL: 当該関数で使用する、condition.shにて定義されるグローバル変数
#                  PARAMETER: 当該関数の各引数の説明
#                    RETURNS: 当該関数が出力する処理結果の説明
#                            （出力しない場合は"---"）
#
# COPYRIGHT NOTE: Copyright(c) 2017 NTT Corporation.
#        CREATED: 2015年3月13日
#        UPDATED: 2017年12月18日
#        VERSION: 2.0.2
#
#============================================================================

set -o nounset                              # Treat unset variables as an error


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  move_local
#   DESCRIPTION:  ローカルサーバファイルコピー・削除
#    PARAMETER1:  コピー元ファイルパス
#    PARAMETER2:  コピー先ファイルパス
#       RETURNS:  ---
#-------------------------------------------------------------------------------
move_local(){
   logger_debug "ローカルサーバファイルコピー・削除"
   mv ${1} "${2}"
   end_if_error $? "ローカルサーバにおける${1}から${2}への移動に失敗しました"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  copy_db_log
#   DESCRIPTION:  DBデータの収集・DBの停止
#    PARAMETER1:  検証結果ファイルの格納ディレクトリ(DBサーバ)
#   USE_GLOBAL1:  DB_IPADDRESS:DBサーバのIPアドレス
#   USE_GLOBAL2:  DB_CLUSTER_LOCATION:PostgreSQL DBクラスタのディレクトリパス 
#   USE_GLOBAL3:  DB_ACTION_LOG_LOCATION:PostgreSQL動作ログのディレクトリパス
#   USE_GLOBAL4:  DB_ACTION_LOG_BACKUP_FILE_NAME:PostgreSQLの動作ログ バックアップファイル名
#   USE_GLOBAL5:  DB_SSH_PORT:DBサーバへSSH接続する際の指定ポート番号
#   USE_GLOBAL6:  DB_MASTER_NAME:PostgreSQLを起動するOSユーザ名
#   USE_GLOBAL7:  DB_PATH_SOURCE_FILE_PATH:PostgreSQLを起動する際にpg_ctlのパスを通すために参照するファイル
#       RETURNS:  ---
#-------------------------------------------------------------------------------
copy_db_log(){
   logger_debug "DBデータの収集・DBの停止"
   ssh -p ${DB_SSH_PORT} ${DB_MASTER_NAME}@${DB_IPADDRESS} "source ${DB_PATH_SOURCE_FILE_PATH};pg_ctl -D ${DB_CLUSTER_LOCATION} stop"
   end_if_error $? "サーバ${DB_IPADDRESS}におけるDBサーバの停止に失敗しました"
   ssh -p ${DB_SSH_PORT} ${DB_MASTER_NAME}@${DB_IPADDRESS} "cd `dirname ${DB_ACTION_LOG_LOCATION}`;tar zcvf \"${1}/${DB_ACTION_LOG_BACKUP_FILE_NAME}\" `basename ${DB_ACTION_LOG_LOCATION}`"
   end_if_warn $? "サーバ${DB_IPADDRESS}における${DB_ACTION_LOG_LOCATION}から${1}/${DB_ACTION_LOG_BACKUP_FILE_NAME}へのバックアップに失敗しました"
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  delete_blogic_data
#   DESCRIPTION:  サンプルアプリケーションが出力した業務データファイルを削除
#   USE_GLOBAL1:  SAMPLE_AP_OUTPUT_LOCATION:サンプルアプリケーションのデータ出力先ファイルパス
#   USE_GLOBAL2:  ASYNC_EXECUTOR_STOP_FILE_PATH:AsyncBatchExecutorの停止ファイル 
#       RETURNS:  --- 
#-------------------------------------------------------------------------------
delete_blogic_data(){
   logger_debug "サンプルアプリケーションが出力した業務データファイルを削除"
   rm ${SAMPLE_AP_OUTPUT_LOCATION}/* 
   end_if_warn $? "${SAMPLE_AP_OUTPUT_LOCATION}/*の削除に失敗しました"
   if [ -e ${ASYNC_EXECUTOR_STOP_FILE_PATH} ]; then
      rm ${ASYNC_EXECUTOR_STOP_FILE_PATH}
      end_if_warn $? "${ASYNC_EXECUTOR_STOP_FILE_PATH}の削除に失敗しました"
   fi
}
