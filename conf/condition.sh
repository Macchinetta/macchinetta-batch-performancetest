#!/bin/bash - 
#=============================================================================
#
#           FILE: condition.sh
#
#    DESCRIPTION: 検証条件　設定ファイル
#
# COPYRIGHT NOTE: Copyright(c) 2017 NTT Corporation.
#        CREATED: 2015年3月13日
#        UPDATED: 2017年12月18日
#        VERSION: 2.0.2
#
#============================================================================

set -o nounset                              # Treat unset variables as an error

#-------------------------------------------------------------------------------
# 試験条件
#-------------------------------------------------------------------------------

#検証種別
# 1 = 基本性能検証
# 2 = 長期安定化試験
TEST_KIND=1

#ジョブNo.
# 設定例：("ジョブNo" "ジョブNo")
JOB_NO=("1" "2" "3")

#データ量番号
# 設定例：("データ量番号" "データ量番号")
TEST_DATA_AMOUNT=("1" "2" "3")

#試行回数
TEST_TIME=3

#測定時間(単位は秒)
TEST_TERM=1

#DBサーバのIPアドレス
DB_IPADDRESS="10.100.71.5"

#検証資材ディレクトリパス
TEST_LOCATION="/home/test/performance"

#サンプルアプリケーションのディレクトリパス
SAMPLE_AP_LOCATION="${TEST_LOCATION}/atrs-batch-2.0.2.RELEASE"

#測定結果のディレクトリパス（バッチサーバ）
RESULT_LOCATION="${TEST_LOCATION}/test_result"

#サンプルアプリケーション動作ログのファイルパス
ACTION_LOG_LOCATION="${TEST_LOCATION}/atrs-batch-2.0.2.RELEASE/logs/atrs-batch-application.log"

#測定結果のディレクトリパス（DBサーバ）
RESULT_DB_LOCATION="/var/lib/pgsql/db_test/test_result_db"

#PostgreSQL DBクラスタのディレクトリパス
DB_CLUSTER_LOCATION="/var/lib/pgsql/9.6/pg_cluster"

#PostgreSQL動作ログのディレクトリパス
DB_ACTION_LOG_LOCATION="/var/lib/pgsql/9.6/pg_cluster/pg_log"

#ログレベル
# ERROR, WARN, INFO, DEBUGから選択して指定
LOG_LEVEL="INFO"

#検証結果ファイル名のプレフィックス
# `を使用したUnixコマンドの実行結果の利用が可能
RESULT_PREFIX="test`date +'%Y%m%d%H%M%S'`"

#サンプルアプリケーション実行時引数
# `を使用したUnixコマンドの実行結果の利用が可能
# 設定例：(["1"]="サンプルAPのジョブNo.1を実行するシェルの引数指定" ["2"]="サンプルAPのジョブNo.2を実行するシェルの引数指定" ["3"]="サンプルAPのジョブNo.3を実行するシェルの引数指定")
declare -A SAMPLE_AP_ARGUMENTS=(["1"]="" ["2"]="" ["3"]="`date +"%Y%m%d" --date "30 day ago"` `date +"%Y%m%d"`")

#-------------------------------------------------------------------------------
# 試験条件（詳細）
#-------------------------------------------------------------------------------

# startAsyncBatchDaemon.shのファイルパス(フルパス)
ASYNC_EXECUTOR_START_PATH=${SAMPLE_AP_LOCATION}/scripts/startAsyncBatchDaemon.sh
# stopAsyncBatchDaemon.shのファイルパス(フルパス)
ASYNC_EXECUTOR_STOP_PATH=${SAMPLE_AP_LOCATION}/scripts/stopAsyncBatchDaemon.sh
# aggregateReservation.shのファイルパス(フルパス)
ASYNC_EXECUTOR_JOB_INSERT_PATH=${SAMPLE_AP_LOCATION}/scripts/aggregateReservation.sh
# ジョブNo.1のファイルパス(フルパス)
SYNC_JOB_NO1_PATH=${SAMPLE_AP_LOCATION}/scripts/JBBA01001.sh
# ジョブNo.2のファイルパス(フルパス)
SYNC_JOB_NO2_PATH=${SAMPLE_AP_LOCATION}/scripts/JBBA02001.sh

# AsyncBatchDaemonの停止ファイルパス
ASYNC_EXECUTOR_STOP_FILE_PATH="/tmp/stop-async-batch-daemon"

# 長期安定化検証の対象Job No.
LONG_TEST_JOB_NO=3
# ジョブ No.の範囲プレフィックス
JOB_NO_PREFIX_FORMAT="^[1|2|3]$"
# 検証データ量 No.の範囲プレフィックス
TEST_DATA_PREFIX_FORMAT="^[1|2|3]$"
# 検証種別の範囲プレフィックス
TEST_KIND_PREFIX_FORMAT="^[1|2]$"
# ジョブ No.リストの要素数最小値
JOB_NO_LIST_ELEMENT_MIN=1
# 検証データ量 No.リストの要素数最小値
TEST_DATA_LIST_ELEMENT_MIN=1
# 試行回数の最小値
TEST_TIME_MIN=1
# 測定時間の最小値
TEST_TERM_MIN=1
# 検証結果ファイル名のプレフィックス制限
RESULT_PREFIX_FORMAT="^[^/]*$"
# 検証データ配置を実施するジョブNo.のプレフィックス
SET_TEST_DATA_PREFIX_FORMAT="^[1]$"

# LoggerのAppenderのリスト
LOGGER_APENDER_LIST=("stdout" "fileout")
# Loggerのファイル出力先
LOG_OUTPUT_PATH="`pwd`/log_output"
# Loggerの出力パターン
LOG_OUTPUT_PATTERN="(%d) %-4r [%t] %-5p %c %x - %m%n"

#PostgreSQL DBクラスタバックアップのファイルパス
DB_CLUSTER_BACKUP_LOCATION="${DB_CLUSTER_LOCATION}.tar.gz"
#検証データ格納するDBのユーザ名
DB_USER_NAME="postgres"
#検証データ格納するDBのデータベース名
DB_DATABASE_NAME="atrs_batch"
#VACUUM ANALYZEのSQL文
VACUUM_ANALYZE_SQL="VACUUM ANALYZE"
#実行中非同期型ジョブ数の取得SQL文
ASYNC_EXECUTE_JOB_NUM_SQL="SELECT count(*) FROM batch_job_execution WHERE status = 'STARTED';"
#最終更新非同期型ジョブの更新時刻の取得SQL文
ASYNC_JOB_LAST_UPDATE_SQL="SELECT to_char(last_updated, 'YYYY/MM/DD HH24:MI:SS') FROM batch_job_execution ORDER BY last_updated DESC LIMIT 1;"
#最終更新非同期型ジョブの更新時刻の取得SQL文(ジョブID指定)
ASYNC_JOB_LAST_UPDATE_SELECTED_JOBID_SQL="SELECT to_char(a.last_updated, 'YYYY/MM/DD HH24:MI:SS') FROM batch_job_execution a, batch_job_instance b WHERE b.job_name='%s' AND a.job_instance_id = b.job_instance_id ORDER BY a.last_updated DESC LIMIT 1;"

#PostgreSQLを起動するOSユーザ名
DB_MASTER_NAME="postgres"
#PostgreSQLを起動する際にpg_ctlのパスを通すために参照するファイル
DB_PATH_SOURCE_FILE_PATH="~/.bash_profile"

#検証データファイルパス
SAMPLE_AP_INPUT_LOCATION="${SAMPLE_AP_LOCATION}/inputFile"
#検証結果ファイル名
PERFORMANCE_RESULT_LOG="${RESULT_PREFIX}.dat"
#HeapStats情報ファイル
HEAPSTATS_PATH="${SAMPLE_AP_LOCATION}/heapstats_*"
#GC情報ファイル
GC_PATH="${SAMPLE_AP_LOCATION}/gc.txt"
#バッチ結果出力パス
SAMPLE_AP_OUTPUT_LOCATION="${SAMPLE_AP_LOCATION}/outputFile"
#フライト情報更新ファイルパス
TEST_FILE_DATA_PATH="${SAMPLE_AP_INPUT_LOCATION}/FlightUpdate.csv"

# 検証データ列(検証データ)
declare -A TEST_DB_DATA_PATH_LIST
TEST_DB_DATA_PATH_LIST=(["1"]="${SAMPLE_AP_LOCATION}/sql/postgres/size1/0*.sql" ["2"]="${SAMPLE_AP_LOCATION}/sql/postgres/size2/0*.sql" ["3"]="${SAMPLE_AP_LOCATION}/sql/postgres/0*.sql")
# 検証データファイルパスコピー元
TEST_FILE_DATA_PATH_PARENT="${SAMPLE_AP_LOCATION}/inputOrg"
# 検証データ列(検証データファイルパスコピー元)
declare -A TEST_FILE_DATA_PATH_LIST
TEST_FILE_DATA_PATH_LIST=(["1"]="${TEST_FILE_DATA_PATH_PARENT}/FlightUpdate_size1.csv" ["2"]="${TEST_FILE_DATA_PATH_PARENT}/FlightUpdate_size2.csv" ["3"]="${TEST_FILE_DATA_PATH_PARENT}/FlightUpdate_size3.csv")
# 集計対象ファイル列 (同期型ジョブのみ)
declare -A TEST_COLLECT_TARGET_PATH_LIST
TEST_COLLECT_TARGET_PATH_LIST=(["1"]="${SAMPLE_AP_INPUT_LOCATION}/FlightUpdate_finish.csv" ["2"]="${SAMPLE_AP_OUTPUT_LOCATION}/*.csv")
# 非同期ジョブの対応ジョブID列(非同期型ジョブのみ)
declare -A JOB_ID_ARRAY
JOB_ID_ARRAY=(["3"]="JBBB01001 JBBB01002 JBBB01003")
# 集計対象ファイル配列の連想配列(非同期型ジョブのみ/配列はJOB_ID_ARRAYの順番に合わせる)
declare -A ASYNC_TEST_COLLECT_TARGET_PATH_LIST
ASYNC_TEST_COLLECT_TARGET_PATH_LIST=(["3"]="'${SAMPLE_AP_OUTPUT_LOCATION}/*_reservation_data.csv' '${SAMPLE_AP_OUTPUT_LOCATION}/route_Aggregation_data.csv' '${SAMPLE_AP_OUTPUT_LOCATION}/fareType_Aggregation_data.csv'")
# 集計対象ファイルのデータ部以外行数の列
declare -A TEST_COLLECT_TARGET_NO_DATA_LINE
TEST_COLLECT_TARGET_NO_DATA_LINE=(["1"]=0 ["2"]=0 ["3"]=1)

#sar情報収集間隔(秒指定)
SAR_INTERVAL=10
#sarプロセス情報出力ファイル名
SAR_PROCESS_INFO_BUFFER_FILE="sar.pid"
#sar出力ファイル名
SAR_FILE_NAME="sar.dat"

#PostgreSQLの動作ログ バックアップファイル名
DB_ACTION_LOG_BACKUP_FILE_NAME="pg_action_log.tar.gz"
#性能検証プログラム実行ごとの結果格納ディレクトリ
TEST_EXECUTION_RESULT_DIR="${RESULT_PREFIX}"

#AsyncBatchDaemonの動作確認対象プロセス名
CHECK_ASYNC_BATCH_DAEMON_PROCESS_NAME="org.terasoluna.batch.async.db.AsyncBatchDaemon"

#DBサーバへSSH接続する際の指定ポート番号
DB_SSH_PORT=22
#ローカルサーバへSSH接続する際の指定ポート番号
LOCAL_SSH_PORT=22
#DBサーバへpsql接続する際の指定ポート番号
DB_PSQL_PORT=5432
