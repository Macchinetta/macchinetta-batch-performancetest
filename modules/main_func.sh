#!/bin/bash - 
#=============================================================================
#
#           FILE: main_func.sh
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

set -o nounset                              # Treat unset variables as an error

#-------------------------------------------------------------------------------
# 外部シェルの読み込み
#-------------------------------------------------------------------------------
. ../modules/initdb_func.sh
. ../modules/job_func.sh
. ../modules/resource_func.sh
. ../modules/collect_func.sh

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  init_log4sh_appender
#   DESCRIPTION:  Log4shのAppender設定を行う
#    PARAMETER1:  Appender名
#   USE_GLOBAL1:  LOG_OUTPUT_PATH:ファイル出力先 
#   USE_GLOBAL2:  LOG_OUTPUT_PATTERN:出力パターン
#       RETURNS:  ---  
#-------------------------------------------------------------------------------
init_log4sh_appender(){   
   logger_addAppender $1
   if [ $1 = "stdout" ]; then
      appender_setType $1 ConsoleAppender
   else
      appender_setType $1 FileAppender
      appender_file_setFile $1 ${LOG_OUTPUT_PATH}
   fi
   appender_setLayout $1 PatternLayout
   appender_setPattern $1 "${LOG_OUTPUT_PATTERN}"
   appender_activateOptions $1
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  init_db_condition 
#   DESCRIPTION:  検証データ投入機能
#    PARAMETER1:  検証データ量 No.
#    PARAMETER2:  ジョブ No.
#   USE_GLOBAL1:  TEST_DB_DATA_PATH_LIST:検証データ列(検証データ)
#   USS_GLOBAL2:  SET_TEST_DATA_PREFIX_FORMAT:検証データ配置を実施するジョブNo.のプレフィックス
#   USE_GLOBAL3:  TEST_FILE_DATA_PATH_LIST: 検証データ列(検証データファイルパスコピー元)
#       RETURNS:  ---  
#-------------------------------------------------------------------------------
init_db_condition(){
   logger_info "検証データ投入機能実行"
   check_db                               # DBの動作状態確認
   clear_db                               # DB初期化
   check_start_db                          # DB起動確認
   logger_debug "insert data path: ${TEST_DB_DATA_PATH_LIST[${1}]}"
   insert_db_data "${TEST_DB_DATA_PATH_LIST[${1}]}" # 検証データ投入
   exec_vacuum_analyze # VACUUM ANALYZEの処理
   check_jobno=`expr ${2} : ${SET_TEST_DATA_PREFIX_FORMAT}`
   if [ ${check_jobno} -ne 0 ]; then
      set_test_data ${TEST_FILE_DATA_PATH_LIST[${1}]} # 検証データ配置
   fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  resource_start
#   DESCRIPTION:  サーバリソース情報の取得開始
#    PARAMETER1:  sarファイル結果格納ディレクトリ（バッチサーバ）
#    PARAMETER2:  sarファイル結果格納ディレクトリ（DBサーバ）
#   USE_GLOBAL1:  DB_IPADDRESS:DBサーバIPアドレス
#   USE_GLOBAL2:  RESULT_LOCATION:測定結果のディレクトリパス（バッチサーバ）
#   USE_GLOBAL3:  RESULT_DB_LOCATION:測定結果のディレクトリパス（DBサーバ）
#   USE_GLOBAL4:  TEST_EXECUTION_RESULT_DIR:性能検証プログラム実行ごとの結果格納ディレクトリ
#   USE_GLOBAL5:  LOCAL_SSH_PORT:ローカルサーバへSSH接続する際の指定ポート番号
#   USE_GLOBAL6:  DB_SSH_PORT:DBサーバへSSH接続する際の指定ポート番号
#   USE_GLOBAL7:  DB_MASTER_NAME:PostgreSQLを起動するOSユーザ名
#       RETURNS:  ---  
#-------------------------------------------------------------------------------
resource_start(){
   logger_info "サーバリソース情報の取得開始"
   resource_start_server "127.0.0.1" "$1" "${RESULT_LOCATION}/${TEST_EXECUTION_RESULT_DIR}" ${LOCAL_SSH_PORT}                # バッチサーバ上でsarを起動
   resource_start_server ${DB_MASTER_NAME}@${DB_IPADDRESS} "$2" "${RESULT_DB_LOCATION}/${TEST_EXECUTION_RESULT_DIR}" ${DB_SSH_PORT}                # DBサーバ上でsarを起動
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  async_exec
#   DESCRIPTION:  非同期型ジョブの実行
#    PARAMETER1:  Job No.
#    PARAMETER2:  試行回数
#    PARAMETER3:  検証結果ファイルの格納ディレクトリ
#   USE_GLOBAL1:  ASYNC_EXECUTOR_JOB_INSERT_PATH:aggregateReservation.shのフルパス
#   USE_GLOBAL2:  ACTION_LOG_LOCATION:サンプルアプリケーション動作ログのファイルパス
#   USE_GLOBAL3:  SAMPLE_AP_ARGUMENTS:サンプルアプリケーション実行時引数
#   USE_GLOBAL4:  TEST_COLLECT_TARGET_NO_DATA_LINE:集計対象ファイルのデータ部以外行数の列
#   USE_GLOBAL5:  JOB_ID_ARRAY:非同期ジョブの対応ジョブID列(非同期型ジョブのみ)
#   USE_GLOBAL6:  ASYNC_TEST_COLLECT_TARGET_PATH_LIST:集計対象ファイル配列の連想配列(非同期型ジョブのみ/配列はJOB_ID_ARRAYの順番に合わせる)
#   USE_GLOBAL7:  ASYNC_JOB_LAST_UPDATE_SQL:最終更新非同期型ジョブの更新時刻の取得SQL文
#   USE_GLOBAL8:  ASYNC_JOB_LAST_UPDATE_SELECTED_JOBID_SQL:最終更新非同期型ジョブの更新時刻の取得SQL文(ジョブID指定)
#       RETURNS:  ---  
#-------------------------------------------------------------------------------
async_exec(){
   logger_info "非同期型ジョブの実行"
   start_time=`get_time`                    # システム現在日時を取得して、バッチ開始時刻とする
   cd `dirname ${ASYNC_EXECUTOR_JOB_INSERT_PATH}`
   shell_name=`basename ${ASYNC_EXECUTOR_JOB_INSERT_PATH}`
   bash ${shell_name} ${SAMPLE_AP_ARGUMENTS[${1}]}              # オンラインAPから予約情報の集計が実行された状況を擬似的に実現するスクリプト(aggregateReservation.sh)を実行
   end_if_error $? "${ASYNC_EXECUTOR_JOB_INSERT_PATH}の実行に失敗しました"
   wait_async_job_end           # 非同期型ジョブの終了を待ち
   data_num_all=0
   sleep 5
   no_data_num=`get_no_data_total_num ${TEST_COLLECT_TARGET_NO_DATA_LINE[${1}]}` # ジョブの処理データ件数を示すファイルにおける、データ部以外の行数の総数を算出する
   job_id_list=(${JOB_ID_ARRAY[${1}]})
   logger_debug "${ASYNC_TEST_COLLECT_TARGET_PATH_LIST[${1}]}"
   collect_target_path_array=(${ASYNC_TEST_COLLECT_TARGET_PATH_LIST[${1}]})
   job_id_count=`expr ${#job_id_list[*]} - 1`
   sleep 5
   for i in `seq 0 ${job_id_count}`; do
      end_time_sql=`printf "${ASYNC_JOB_LAST_UPDATE_SELECTED_JOBID_SQL}" ${job_id_list[${i}]}` # 非同期型ジョブの終了した日時をサンプルアプリケーションの動作ログから取得(JOBIDごと)
      end_time_jobid=`get_end_time "${end_time_sql}"`
      data_num_jobid=`get_data_num "${collect_target_path_array[${i}]//\'/}" ${no_data_num}`                  # ジョブが処理したデータ件数を取得する
      diff_time_jobid=`calc_diff_time "${end_time_jobid}" "${start_time}"` # 応答時間（ターンアラウンドタイム）の取得
      throughput_jobid=`calc_throughput ${data_num_jobid} ${diff_time_jobid}` # スループットの取得
      export_job_log "${1}(${job_id_list[${i}]})" ${data_num_jobid} ${2} "${start_time}" "${end_time_jobid}" ${diff_time_jobid} ${throughput_jobid} "${3}" # 検証結果ファイルの出力
      data_num_all=`expr ${data_num_all} + ${data_num_jobid}`
   done
   end_time_all=`get_end_time "${ASYNC_JOB_LAST_UPDATE_SQL}"`             # 非同期型ジョブの終了した日時をサンプルアプリケーションの動作ログから取得
   diff_time_all=`calc_diff_time "${end_time_all}" "${start_time}"` # 応答時間（ターンアラウンドタイム）の取得
   throughput_all=`calc_throughput ${data_num_all} ${diff_time_all}` # スループットの取得
   export_job_log "${1}(ALL)" ${data_num_all} ${2} "${start_time}" "${end_time_all}" ${diff_time_all} ${throughput_all} "${3}" # 検証結果ファイルの出力
   sleep 5
   bash ${ASYNC_EXECUTOR_STOP_PATH} # AsyncBatchDaemonの停止
   end_if_error $? "AsyncBatchDaemonの停止に失敗しました"
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  sync_exec
#   DESCRIPTION:  同期型ジョブ実行の場合
#    PARAMETER1:  実行する同期型ジョブ起動シェルスクリプトのフルパス
#    PARAMETER2:  Job No.
#    PARAMETER3:  試行回数
#    PARAMETER4:  検証結果ファイルの格納ディレクトリ
#   USE_GLOBAL1:  TEST_COLLECT_TARGET_PATH_LIST:集計対象ファイル列
#   USE_GLOBAL2:  SAMPLE_AP_ARGUMENTS:サンプルアプリケーション実行時引数
#   USE_GLOBAL3:  TEST_COLLECT_TARGET_NO_DATA_LINE:集計対象ファイルのデータ部以外行数の列
#       RETURNS:  ---  
#-------------------------------------------------------------------------------
sync_exec(){
   logger_info "同期型ジョブ実行"
   start_time=`get_time`                   # システム現在日時を取得して、バッチ開始時刻とする
   cd `dirname ${1}`
   shell_name=`basename ${1}`
   bash ${shell_name} ${SAMPLE_AP_ARGUMENTS[${2}]}                         # 実行するジョブNo.に合わせてフライト情報更新ジョブおよびフライト情報退避ジョブの起動シェルスクリプトを実行
   end_if_error $? "${1}の実行に失敗しました"
   end_time=`get_time`                     # サンプルアプリケーション（起動シェルスクリプト）の終了（リターンコード取得）時点のシステム現在日時を取得
   no_data_num=`get_no_data_total_num ${TEST_COLLECT_TARGET_NO_DATA_LINE[${2}]}` # ジョブの処理データ件数を示すファイルにおける、データ部以外の行数の総数を算出する
   data_num=`get_data_num "${TEST_COLLECT_TARGET_PATH_LIST[${2}]}" ${no_data_num}`          # ジョブが処理したデータ件数を取得する
   diff_time=`calc_diff_time "${end_time}" "${start_time}"` # 応答時間（ターンアラウンドタイム）の取得
   throughput=`calc_throughput ${data_num} ${diff_time}` # スループットの取得
   export_job_log ${2} ${data_num} ${3} "${start_time}" "${end_time}" ${diff_time} ${throughput} "${4}" # 検証結果ファイルの出力
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  resource_stop
#   DESCRIPTION:  サーバリソース情報の取得終了
#   USE_GLOBAL1:  DB_IPADDRESS:DBサーバIPアドレス
#   USE_GLOBAL2:  RESULT_LOCATION:測定結果のディレクトリパス（バッチサーバ）
#   USE_GLOBAL3:  RESULT_DB_LOCATION:測定結果のディレクトリパス（DBサーバ）
#   USE_GLOBAL4:  TEST_EXECUTION_RESULT_DIR:性能検証プログラム実行ごとの結果格納ディレクトリ
#   USE_GLOBAL5:  DB_SSH_PORT:DBサーバへSSH接続する際の指定ポート番号
#   USE_GLOBAL6:  LOCAL_SSH_PORT:ローカルサーバへSSH接続する際の指定ポート番号
#   USE_GLOBAL7:  DB_MASTER_NAME:PostgreSQLを起動するOSユーザ名
#       RETURNS:  ---  
#-------------------------------------------------------------------------------
resource_stop(){
   logger_info "サーバリソース情報の取得終了"
   resource_stop_server "127.0.0.1" "${RESULT_LOCATION}/${TEST_EXECUTION_RESULT_DIR}" ${LOCAL_SSH_PORT}                 # バッチサーバ上でsarを停止
   resource_stop_server ${DB_MASTER_NAME}@${DB_IPADDRESS} "${RESULT_DB_LOCATION}/${TEST_EXECUTION_RESULT_DIR}" ${DB_SSH_PORT}                 # DBサーバ上でsarを停止
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  collect_result
#   DESCRIPTION:  検証結果収集機能（検証結果の削除） 
#    PARAMETER1:  検証結果ファイルの格納ディレクトリ(バッチサーバ)
#    PARAMETER2:  検証結果ファイルの格納ディレクトリ(DBサーバ)
#   USE_GLOBAL1:  HEAPSTATS_PATH:HeapStats情報ファイル
#   USE_GLOBAL2:  GC_PATH:GCログ
#   USE_GLOBAL3:  ACTION_LOG_LOCATION:サンプルアプリケーションの動作ログ
#       RETURNS:  ---  
#-------------------------------------------------------------------------------
collect_result(){
   logger_info "検証結果収集機能（検証結果の削除）の実行"
   move_local "${HEAPSTATS_PATH}" "${1}"                           # HeapStats情報ファイル
   move_local "${GC_PATH}" "${1}"                           # GCログ
   move_local "${ACTION_LOG_LOCATION}" "${1}"                              # サンプルアプリケーションの動作ログ
   copy_db_log "${2}"                              # PostgreSQLの動作ログ(DBの停止を含む)
   delete_blogic_data                       # サンプルアプリケーションが出力した業務データファイルを削除
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  check_end
#   DESCRIPTION:  「測定時間」に応じて、繰り返し測定を行う
#    PARAMETER1:  測定開始時間
#    PARAMETER2:　測定時間
#       RETURNS:  終了：0 続行:1
#-------------------------------------------------------------------------------
check_end(){
   now_time=`get_time`
   running_time=`calc_diff_time "${now_time}" "${1}"`
   if [ ${running_time} -gt ${2} ]; then
      echo "0"
   else
      echo "1"
   fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  make_result_dir
#   DESCRIPTION:  検証結果ファイルの格納ディレクトリの作成
#    PARAMETER1:  作成先ユーザ名@IPアドレス
#    PARAMETER2:  ディレクトリパス 
#    PARAMETER3:  ssh接続ポート 
#       RETURNS:  ---
#-------------------------------------------------------------------------------
make_result_dir(){
   ssh -p ${3} ${1} "mkdir \"${2}\""
   end_if_error $? "サーバ${1}にてディレクトリ${2}の作成に失敗しました"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  check_async_executor
#   DESCRIPTION:  AsyncBatchDaemonの動作状態確認
#   USE_GLOBAL1:  CHECK_ASYNC_BATCH_DAEMON_PROCESS_NAME:AsyncBatchDaemonの動作確認対象プロセス名
#       RETURNS:  ---
#-------------------------------------------------------------------------------
check_async_executor(){
   logger_debug "AsyncBatchDaemonの動作状態確認"
   result=`ps -ef | grep ${CHECK_ASYNC_BATCH_DAEMON_PROCESS_NAME} | grep -vc grep`
   return_code=$?
   if [ ${return_code} -ne 1 -o ${result} -ge 1 ]; then
      logger_debug "return code: ${return_code}, result: ${result}"
      end_if_error 1 "既にAsyncBatchDaemonが起動しています"
   fi
}
