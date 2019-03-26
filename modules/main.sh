#!/bin/bash - 
#=============================================================================
#
#           FILE: main.sh
#
#    DESCRIPTION: 「検証実行機能」用関数モジュール
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

#set -o nounset                              # Treat unset variables as an error

#-------------------------------------------------------------------------------
# 外部シェルの読み込み
#-------------------------------------------------------------------------------
. ../conf/condition.sh
. ../modules/main_func.sh
. ../modules/common_func.sh

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  base_run
#   DESCRIPTION:  
#    PARAMETER1:  検証データ量 No.
#    PARAMETER2:  ジョブ No.
#    PARAMETER3:  試行回数
#    PARAMETER4:  検証回数
#   USE_GLOBAL1:  TEST_EXECUTION_RESULT_DIR:性能検証プログラム実行ごとの結果格納ディレクトリ
#   USE_GLOBAL2:  DB_IPADDRESS:DBサーバIPアドレス
#   USE_GLOBAL3:  RESULT_DB_LOCATION:測定結果のディレクトリパス（DBサーバ）
#   USE_GLOBAL4:  RESULT_LOCATION:測定結果のディレクトリパス（バッチサーバ）
#   USE_GLOBAL5:  ASYNC_EXECUTOR_START_PATH:startAsyncBatchDaemon.shのファイルパス
#   USE_GLOBAL6:  ASYNC_EXECUTOR_STOP_PATH:stopAsyncBatchDaemon.shのファイルパス
#   USE_GLOBAL7:  SYNC_JOB_NO1_PATH:ジョブNo.1のファイルパス
#   USE_GLOBAL8:  SYNC_JOB_NO2_PATH:ジョブNo.2のファイルパス
#   USE_GLOBAL9:  DB_SSH_PORT:DBサーバへSSH接続する際の指定ポート番号
#  USE_GLOBAL10:  LOCAL_SSH_PORT:ローカルサーバへSSH接続する際の指定ポート番号
#  USE_GLOBAL11:  CHECK_ASYNC_BATCH_EXECUTOR_PROCESS_NAME:AsyncBatchExectorの動作確認対象プロセス名
#  USE_GLOBAL12:  DB_MASTER_NAME:PostgreSQLを起動するOSユーザ名
#       RETURNS:  ---  
#-------------------------------------------------------------------------------
base_run(){
   logger_info "${4}回目の検証（試行回数:${3}, 検証データ量 No.${1}, ジョブ No.${2}）の実施"
   result_dir="${TEST_EXECUTION_RESULT_DIR}/${4}_${3}_${1}_${2}"
   make_result_dir ${DB_MASTER_NAME}@${DB_IPADDRESS} "${RESULT_DB_LOCATION}/${result_dir}" ${DB_SSH_PORT}  # 検証結果ファイルの格納ディレクトリの作成(DBサーバ)
   make_result_dir "127.0.0.1" "${RESULT_LOCATION}/${result_dir}" ${LOCAL_SSH_PORT} # 検証結果ファイルの格納ディレクトリの作成(バッチサーバ)
   init_db_condition ${1} ${2} # 検証データ投入機能
   resource_start "${RESULT_LOCATION}/${result_dir}" "${RESULT_DB_LOCATION}/${result_dir}" # サーバリソース情報の取得開始
   if [ ${2} -eq 3 ]; then  # 非同期型ジョブ実行の場合
      check_async_executor # AsyncBatchDaemonの動作状態確認
      bash ${ASYNC_EXECUTOR_START_PATH} & # AsyncBatchDaemonの起動
      sleep 1
      result=`ps -ef | grep ${CHECK_ASYNC_BATCH_DAEMON_PROCESS_NAME} | grep -vc grep`
      return_code=$?
      if [ ${return_code} -eq 1 -a ${result} -eq 0 ]; then
         end_if_error 1 "AsyncBatchDaemonの起動に失敗しました"
      fi
      async_exec ${2} ${3} "${RESULT_LOCATION}/${result_dir}" # 非同期型ジョブの実行
   elif [ ${2} -eq 1 ]; then # 同期型ジョブ実行の場合
      sync_exec ${SYNC_JOB_NO1_PATH} ${2} ${3} "${RESULT_LOCATION}/${result_dir}"
   elif [ ${2} -eq 2 ]; then # 同期型ジョブ実行の場合
      sync_exec ${SYNC_JOB_NO2_PATH} ${2} ${3} "${RESULT_LOCATION}/${result_dir}"
   fi
   resource_stop # サーバリソース情報の取得終了
   collect_result "${RESULT_LOCATION}/${result_dir}" "${RESULT_DB_LOCATION}/${result_dir}" # 検証結果収集機能
   logger_info "${4}回目の検証（試行回数:${3}, 検証データ量 No.${1}, ジョブ No.${2}）が完了しました"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  base_cycle
#   DESCRIPTION:  測定の繰り返し・検証結果格納ファイル格納親ディレクトリの作成（基本性能検証） 
#   USE_GLOBAL1:  TEST_TIME:試行回数
#   USE_GLOBAL2:  TEST_DATA_AMOUNT:検証データ量
#   USE_GLOBAL3:  JOB_NO:ジョブNo.
#   USE_GLOBAL4:  TEST_EXECUTION_RESULT_DIR:性能検証プログラム実行ごとの結果格納ディレクトリ
#   USE_GLOBAL5:  DB_IPADDRESS:DBサーバIPアドレス
#   USE_GLOBAL6:  RESULT_DB_LOCATION:測定結果のディレクトリパス（DBサーバ）
#   USE_GLOBAL7:  RESULT_LOCATION:測定結果のディレクトリパス（バッチサーバ）
#   USE_GLOBAL8:  DB_SSH_PORT:DBサーバへSSH接続する際の指定ポート番号
#   USE_GLOBAL9:  LOCAL_SSH_PORT:ローカルサーバへSSH接続する際の指定ポート番号
#  USE_GLOBAL10:  DB_MASTER_NAME:PostgreSQLを起動するOSユーザ名
#       RETURNS:  ---  
#-------------------------------------------------------------------------------
base_cycle(){
   logger_info '基本性能検証実施'
   make_result_dir ${DB_MASTER_NAME}@${DB_IPADDRESS} "${RESULT_DB_LOCATION}/${TEST_EXECUTION_RESULT_DIR}" ${DB_SSH_PORT}  # 検証結果ファイルの格納親ディレクトリの作成(DBサーバ)
   make_result_dir "127.0.0.1" "${RESULT_LOCATION}/${TEST_EXECUTION_RESULT_DIR}" ${LOCAL_SSH_PORT} # 検証結果ファイルの格納親ディレクトリの作成(バッチサーバ)
   counter=0
   for cnt in `seq 1 ${TEST_TIME}`
   do
      for amount in ${TEST_DATA_AMOUNT[@]}
      do
         for jno in ${JOB_NO[@]}
         do
            counter=`expr ${counter} + 1`
            base_run ${amount} ${jno} ${cnt} ${counter}
         done
      done
   done
   logger_info 'すべての基本性能検証が完了しました'
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  check_test_element
#   DESCRIPTION:  検証種別、検証データ量No. ジョブNo.のリスト、試行回数、測定時間、検証結果ファイル名のプレフィックス制限のチェック
#   USE_GLOBAL1:  TEST_KIND:検証種別
#   USE_GLOBAL2:  TEST_KIND_PREFIX_FORMAT:検証種別の範囲プレフィックス
#   USE_GLOBAL3:  TEST_DATA_AMOUNT:検証データ量
#   USE_GLOBAL4:  TEST_DATA_LIST_ELEMENT_MIN:検証データ量 No.リストの要素数最小値
#   USE_GLOBAL5:  JOB_NO:ジョブNo.
#   USE_GLOBAL6:  JOB_NO_LIST_ELEMENT_MIN:ジョブ No.リストの要素数最小値
#   USE_GLOBAL7:  TEST_TIME:試行回数
#   USE_GLOBAL8:  TEST_TIME_MIN:試行回数の最小値
#   USE_GLOBAL9:  TEST_TERM:測定時間(単位は秒)
#   USE_GLOBAL10: TEST_TERM_MIN:測定時間の最小値
#   USE_GLOBAL11: RESULT_PREFIX:検証結果ファイル名のプレフィックス
#   USE_GLOBAL12: RESULT_PREFIX_FORMAT:検証結果ファイル名のプレフィックス制限
#       RETURNS:  ---  
#-------------------------------------------------------------------------------
check_test_element(){
   end_flag=0
   error_list_flag=0
   logger_debug '検証データ量No. ジョブNo.のリスト、試行回数、測定時間、検証結果ファイル名のプレフィックス制限のチェック'
   check_test_kind=`expr ${TEST_KIND} : "${TEST_KIND_PREFIX_FORMAT}"`
   if [ ${check_test_kind} -eq 0 ]; then
      logger_error "検証種別${TEST_KIND}が不正です"
      end_flag=1
   fi
   if [ ${#TEST_DATA_AMOUNT[*]} -lt ${TEST_DATA_LIST_ELEMENT_MIN} ]; then
      logger_error "検証データ量 No.のリストの要素数が不正です"
      end_flag=1
      error_list_flag=1
   fi
   if [ ${#JOB_NO[*]} -lt ${JOB_NO_LIST_ELEMENT_MIN} ]; then
      logger_error "ジョブ No.のリストの要素数が不正です"
      end_flag=1
      error_list_flag=1
   fi
   check_test_time=`expr ${TEST_TIME} : "^[0-9]\+$"`
   if [ ${check_test_time} -eq 0 ]; then
      logger_error "試行回数${TEST_TIME}が不正です"
      end_flag=1
   else
      if [ ${TEST_TIME} -lt ${TEST_TIME_MIN} ]; then
         logger_error "試行回数${TEST_TIME}が不正です"
         end_flag=1
      fi
   fi
   check_test_distance=`expr ${TEST_TERM} : "^[0-9]\+$"`
   if [ ${check_test_distance} -eq 0 ]; then
      logger_error "測定時間${TEST_TERM}が不正です"
      end_flag=1
   else
      if [ ${TEST_TERM} -lt ${TEST_TERM_MIN} ]; then
         logger_error "測定時間${TEST_TERM}が不正です"
         end_flag=1
      fi
   fi
   check_result_prefix=`expr "${RESULT_PREFIX}" : "${RESULT_PREFIX_FORMAT}"`
   if [ ${check_result_prefix} -eq 0 ]; then
      logger_error "検証結果ファイル名のプレフィックス${RESULT_PREFIX}が不正です"
      end_flag=1
   fi
   for key in ${!SAMPLE_AP_ARGUMENTS[@]};
   do
      check_sample_ap_arguments_key=`expr ${key} : "${JOB_NO_PREFIX_FORMAT}"`
      if [ ${check_sample_ap_arguments_key} -eq 0 ]; then
         logger_error "サンプルアプリケーション実行時引数のキー${key}が不正です"
         end_flag=1
      fi
   done
   if [ ${error_list_flag} -eq 0 ]; then
      for amount in ${TEST_DATA_AMOUNT[@]}
      do
         for jno in ${JOB_NO[@]}
         do
            job_element_result=`check_job_element ${amount} ${jno}`
            if [ ${job_element_result} -ne 0 ]; then
               logger_error "検証データ量 No.${amount}、またはジョブNo.${jno}が不正です。"
               end_flag=1
            fi
         done
      done
   fi
   end_if_error ${end_flag} "検証条件が不正です"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  check_job_element
#   DESCRIPTION:  検証データ量No. ジョブNo.のチェック
#    PARAMETER1:  検証データ量 No.
#    PARAMETER2:  ジョブ No.
#   USE_GLOBAL1:  TEST_DATA_PREFIX_FORMAT:検証データ量 No.の範囲プレフィックス
#   USE_GLOBAL2:  JOB_NO_PREFIX_FORMAT:ジョブ No.の範囲プレフィックス
#       RETURNS:  チェック結果：0 正常、1 異常
#-------------------------------------------------------------------------------
check_job_element(){
   error_flag=0
   check_datano=`expr ${1} : "${TEST_DATA_PREFIX_FORMAT}"`
   if [ ${check_datano} -eq 0 ]; then
      error_flag=1
   fi
   check_jobno=`expr ${2} : "${JOB_NO_PREFIX_FORMAT}"`
   if [ ${check_jobno} -eq 0 ]; then
      error_flag=1
   fi
   echo ${error_flag}
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  long_run
#   DESCRIPTION:  長期安定化検証実施
#   USE_GLOBAL1:  TEST_EXECUTION_RESULT_DIR:性能検証プログラム実行ごとの結果格納ディレクトリ
#   USE_GLOBAL2:  DB_IPADDRESS:DBサーバIPアドレス
#   USE_GLOBAL3:  RESULT_DB_LOCATION:測定結果のディレクトリパス（DBサーバ）
#   USE_GLOBAL4:  RESULT_LOCATION:測定結果のディレクトリパス（バッチサーバ）
#   USE_GLOBAL5:  ASYNC_EXECUTOR_START_PATH:startAsyncBatchDaemon.shのファイルパス
#   USE_GLOBAL6:  ASYNC_EXECUTOR_STOP_PATH:stopAsyncBatchDaemon.shのファイルパス
#   USE_GLOBAL7:  TEST_DATA_AMOUNT:検証データ量
#   USE_GLOBAL8:  LONG_TEST_JOB_NO:長期安定化検証の対象Job No.
#   USE_GLOBAL9:  DB_SSH_PORT:DBサーバへSSH接続する際の指定ポート番号
#  USE_GLOBAL10:  LOCAL_SSH_PORT:ローカルサーバへSSH接続する際の指定ポート番号
#  USE_GLOBAL11:  CHECK_ASYNC_BATCH_DAEMON_PROCESS_NAME:AsyncBatchDaemonの動作確認対象プロセス名
#  USE_GLOBAL12:  DB_MASTER_NAME:PostgreSQLを起動するOSユーザ名
#       RETURNS:  --- 
#-------------------------------------------------------------------------------
long_run(){
   logger_info '長期安定化検証実施'
   make_result_dir ${DB_MASTER_NAME}@${DB_IPADDRESS} "${RESULT_DB_LOCATION}/${TEST_EXECUTION_RESULT_DIR}" ${DB_SSH_PORT}  # 検証結果ファイルの格納親ディレクトリの作成(DBサーバ)
   make_result_dir "127.0.0.1" "${RESULT_LOCATION}/${TEST_EXECUTION_RESULT_DIR}" ${LOCAL_SSH_PORT} # 検証結果ファイルの格納親ディレクトリの作成(バッチサーバ)
   result_dir="${TEST_EXECUTION_RESULT_DIR}/long_run"
   make_result_dir ${DB_MASTER_NAME}@${DB_IPADDRESS} "${RESULT_DB_LOCATION}/${result_dir}" ${DB_SSH_PORT}  # 検証結果ファイルの格納ディレクトリの作成(DBサーバ)
   make_result_dir "127.0.0.1" "${RESULT_LOCATION}/${result_dir}" ${LOCAL_SSH_PORT} # 検証結果ファイルの格納ディレクトリの作成(DBサーバ)
   resource_start "${RESULT_LOCATION}/${result_dir}" "${RESULT_DB_LOCATION}/${result_dir}"                          # サーバリソース情報の取得開始
   init_db_condition ${TEST_DATA_AMOUNT[0]} ${LONG_TEST_JOB_NO} # 検証データ投入機能
   check_async_executor # AsyncBatchExecutorの動作状態確認
   bash ${ASYNC_EXECUTOR_START_PATH} &         # AsyncBatchDaemonの起動
   sleep 1
   result=`ps -ef | grep ${CHECK_ASYNC_BATCH_DAEMON_PROCESS_NAME} | grep -vc grep`
   return_code=$?
   if [ ${return_code} -eq 1 -a ${result} -eq 0 ]; then
      end_if_error 1 "AsyncBatchDaemonの起動に失敗しました"
   fi
   starttime=`get_time`
   counter=0
   while [ 1 ]
   do
      counter=`expr ${counter} + 1`
      end_check=`check_end "${starttime}" ${TEST_TERM}`
      if [ ${end_check} -eq 0 ]; then
         break
      else
         async_exec ${LONG_TEST_JOB_NO} ${counter} "${RESULT_LOCATION}/${result_dir}" #  非同期型ジョブの実行
      fi
   done
   resource_stop                           # サーバリソース情報の取得終了
   collect_result "${RESULT_LOCATION}/${result_dir}" "${RESULT_DB_LOCATION}/${result_dir}" # 検証結果収集機能
   logger_info '長期安定化検証が完了しました'
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  exec_test
#   DESCRIPTION:  検証内容の分岐
#   USE_GLOBAL1:  TEST_KIND:検証種別
#       RETURNS:  ---  
#-------------------------------------------------------------------------------
exec_test(){
   logger_debug '検証内容の分岐'
   if [ ${TEST_KIND} -eq 1 ]; then
      base_cycle
   elif [ ${TEST_KIND} -eq 2 ]; then
      long_run
   fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  init_log4sh
#   DESCRIPTION:  Log4shの設定
#   USE_GLOBAL1:  LOGGER_APENDER_LIST:LoggerのAppenderのリスト
#   USE_GLOBAL2:  LOG_LEVEL:ログレベル
#       RETURNS:  ---  
#-------------------------------------------------------------------------------
init_log4sh(){
   LOG4SH_CONFIGURATION='none' . ../lib/log4sh
   log4sh_resetConfiguration
   logger_setLevel ${LOG_LEVEL}
   ret=`logger_getLevel`
   if [ "${ret}" != "${LOG_LEVEL}" ]; then
      echo "ログレベル${LOG_LEVEL}が不正です。"
      kill $$
   fi
   for adder in ${LOGGER_APENDER_LIST[@]}
   do
      init_log4sh_appender ${adder}
   done
   logger_debug 'Log4shの設定完了'
}

#-------------------------------------------------------------------------------
# start execution
#-------------------------------------------------------------------------------
init_log4sh                                     # Log4shの設定
check_test_element                               # 検証データ量No. ジョブNo.のリスト、試行回数、測定時間、検証結果ファイル名のプレフィックス制限のチェック
exec_test                                           # 検証内容の分岐


