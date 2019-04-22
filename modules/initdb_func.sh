#!/bin/bash - 
#=============================================================================
#
#           FILE: initdb_func.sh
#
#    DESCRIPTION: 「検証データ投入機能」用関数モジュール
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
#          NAME:  check_db
#   DESCRIPTION:  DBの動作状態確認
#   USE_GLOBAL1:  DB_IPADDRESS:DBサーバのIPアドレス
#   USE_GLOBAL2:  DB_SSH_PORT:DBサーバへSSH接続する際の指定ポート番号
#   USE_GLOBAL3:  DB_MASTER_NAME:PostgreSQLを起動するOSユーザ名
#   USE_GLOBAL4:  DB_CLUSTER_LOCATION:PostgreSQL DBクラスタのディレクトリパス
#       RETURNS:  ---
#-------------------------------------------------------------------------------
check_db(){
   logger_debug "DBの動作状態確認"
   ssh -p ${DB_SSH_PORT} ${DB_MASTER_NAME}@${DB_IPADDRESS} "source ${DB_PATH_SOURCE_FILE_PATH}; pg_ctl -D ${DB_CLUSTER_LOCATION} status"
   return_code=$?
   if [ ${return_code} -eq 0 ]; then
      logger_debug "return code: ${return_code}"
      end_if_error 1 "既にPostgreSQLサーバが起動しているか、PostgreSQL DBクラスタのディレクトリパス${DB_CLUSTER_LOCATION}を確かめてください"
   fi
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  clear_db
#   DESCRIPTION:  DB初期化
#   USE_GLOBAL1:  DB_IPADDRESS:DBサーバのIPアドレス
#   USE_GLOBAL2:  DB_CLUSTER_LOCATION:PostgreSQL DBクラスタのディレクトリパス
#   USE_GLOBAL3:  DB_CLUSTER_BACKUP_LOCATION:PostgreSQL DBクラスタバックアップのファイルパス
#   USE_GLOBAL4:  DB_SSH_PORT:DBサーバへSSH接続する際の指定ポート番号
#   USE_GLOBAL5:  DB_MASTER_NAME:PostgreSQLを起動するOSユーザ名
#   USE_GLOBAL6:  DB_PATH_SOURCE_FILE_PATH:PostgreSQLを起動する際にpg_ctlのパスを通すために参照するファイル
#       RETURNS:  ---
#-------------------------------------------------------------------------------
clear_db(){
   logger_info "DB初期化"
   cluster_base=`dirname ${DB_CLUSTER_LOCATION}`
   ssh -p ${DB_SSH_PORT} ${DB_MASTER_NAME}@${DB_IPADDRESS} "rm -r ${DB_CLUSTER_LOCATION}"                          # DBクラスタの削除
   end_if_error $? "サーバ${DB_IPADDRESS}のDBクラスタ${DB_CLUSTER_LOCATION}の削除に失敗しました。"
   ssh -p ${DB_SSH_PORT} ${DB_MASTER_NAME}@${DB_IPADDRESS} "cd ${cluster_base}; tar zxvf ${DB_CLUSTER_BACKUP_LOCATION}"                 # DBクラスタの移動
   end_if_error $? "サーバ${DB_IPADDRESS}のDBクラスタアーカイブ${DB_CLUSTER_BACKUP_LOCATION}の展開に失敗しました"
   ssh -p ${DB_SSH_PORT} ${DB_MASTER_NAME}@${DB_IPADDRESS} "source ${DB_PATH_SOURCE_FILE_PATH}; pg_ctl -w -D ${DB_CLUSTER_LOCATION} start > /dev/null"        # DBの起動(起動完了まで待機)
   end_if_error $? "PostgreSQLの起動に失敗しました"
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  check_start_db
#   DESCRIPTION:  DB起動確認
#   USE_GLOBAL1:  DB_IPADDRESS:DBサーバのIPアドレス
#   USE_GLOBAL2:  DB_USER_NAME:検証データ格納するDBのユーザ名 
#   USE_GLOBAL3:  DB_DATABASE_NAME:検証データ格納するDBのデータベース名
#   USE_GLOBAL4:  DB_PSQL_PORT:DBサーバへpsql接続する際の指定ポート番号
#       RETURNS:  ---
#-------------------------------------------------------------------------------
check_start_db(){
   logger_debug "DB起動確認"
   psql -p ${DB_PSQL_PORT} -h ${DB_IPADDRESS} -U ${DB_USER_NAME} -d ${DB_DATABASE_NAME} -c 'SELECT 1' > /dev/null
   end_if_error $? "PostgreSQLの起動に失敗しました"
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  exec_vacuum_analyze
#   DESCRIPTION:  VACUUM ANALYZEの処理
#   USE_GLOBAL1:  DB_IPADDRESS:DBサーバのIPアドレス
#   USE_GLOBAL2:  DB_USER_NAME:検証データ格納するDBのユーザ名
#   USE_GLOBAL3:  DB_DATABASE_NAME:検証データ格納するDBのデータベース名
#   USE_GLOBAL4:  VACUUM_ANALYZE_SQL:VACUUM ANALYZEのSQL構文
#   USE_GLOBAL5:  DB_PSQL_PORT:DBサーバへpsql接続する際の指定ポート番号
#       RETURNS:  --- 
#-------------------------------------------------------------------------------
exec_vacuum_analyze(){
   logger_debug "VACUUM ANALYZEの処理"
   psql -p ${DB_PSQL_PORT} -h ${DB_IPADDRESS} -U ${DB_USER_NAME} -d ${DB_DATABASE_NAME} -c "${VACUUM_ANALYZE_SQL}"
   end_if_error $? "VACUUM ANALYZE[${VACUUM_ANALYZE_SQL}]の実行に失敗しました"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  insert_db_data
#   DESCRIPTION:  検証データ量に対応した業務データ（フライト情報テーブルデータ、予約情報テーブルデータ）を利用して、検証データを対象テーブルに投入
#    PARAMETER1:  検証データパス
#   USE_GLOBAL1:  DB_IPADDRESS:DBサーバのIPアドレス  
#   USE_GLOBAL2:  DB_USER_NAME:検証データ格納するDBのユーザ名
#   USE_GLOBAL3:  DB_DATABASE_NAME:検証データ格納するDBのデータベース名
#   USE_GLOBAL4:  DB_PSQL_PORT:DBサーバへpsql接続する際の指定ポート番号
#       RETURNS:  ---
#-------------------------------------------------------------------------------
insert_db_data(){
   logger_info "検証データ投入"
   logger_debug "execute sql file path : ${1}"
   for sql_file in `ls ${1}` 
   do
      logger_debug "execute sql file : ${sql_file}"
      psql -p ${DB_PSQL_PORT} -h ${DB_IPADDRESS} -U ${DB_USER_NAME} -d ${DB_DATABASE_NAME} -f ${sql_file}
      end_if_error $? "検証データ投入に失敗しました"
   done
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  set_test_data
#   DESCRIPTION:  指定されたデータ量に対応したフライト情報更新ファイルを所定のファイルパスに配置
#    PARAMETER1:  検証データファイルパスコピー元ファイルパス
#   USE_GLOBAL1:  SAMPLE_AP_INPUT_LOCATION:ファイルのコピー先ディレクトリパス
#   USE_GLOBAL2:  TEST_FILE_DATA_PATH:フライト情報更新ファイルパス
#       RETURNS:  ---
#-------------------------------------------------------------------------------
set_test_data(){
   logger_info "検証データファイル配置"
   if [ ! -z "`ls ${SAMPLE_AP_INPUT_LOCATION}`" ]; then
      rm ${SAMPLE_AP_INPUT_LOCATION}/*
      end_if_error $? "配置済みの検証データのクリーンアップに失敗しました"
   fi
   cp ${1} ${TEST_FILE_DATA_PATH}
   end_if_error $? "検証データファイル配置に失敗しました"
}
