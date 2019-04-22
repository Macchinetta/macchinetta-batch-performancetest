#!/bin/bash - 
#=============================================================================
#
#           FILE: resource_func.sh
#
#    DESCRIPTION: 「検証実行機能」の「サーバリソース情報の取得機能」用関数モジュール
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
#          NAME:  resource_start_server
#   DESCRIPTION:  sarを起動
#    PARAMETER1:  起動対象サーバIPアドレス
#    PARAMETER2:  sarファイル結果格納ディレクトリ
#    PARAMETER3:  sarプロセス情報格納ディレクトリ
#    PARAMETER4:  SSH接続PORT番号
#   USE_GLOBAL1:  SAR_INTERVAL:出力間隔
#   USE_GLOBAL2:  SAR_PROCESS_INFO_BUFFER_FILE:sarプロセス情報出力ファイル名
#   USE_GLOBAL3:  SAR_FILE_NAME:出力sarファイル名
#       RETURNS:  ---  
#-------------------------------------------------------------------------------
resource_start_server(){
   logger_debug "sarを起動"
   ssh -p ${4} -f ${1} "sar -A -o \"${2}/${SAR_FILE_NAME}\" ${SAR_INTERVAL} > /dev/null & PID=\`jobs -p %+\`; echo \${PID} > \"${3}/${SAR_PROCESS_INFO_BUFFER_FILE}\""
   end_if_error $? "サーバ${1}におけるsarの起動に失敗しました"
   sleep 1
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  resource_stop_server
#   DESCRIPTION:  sarを停止
#    PARAMETER1:  起動対象サーバIPアドレス
#    PARAMETER2:  sarプロセス情報格納ディレクトリ
#    PARAMETER3:  SSH接続PORT番号
#   USE_GLOBAL1:  SAR_PROCESS_INFO_BUFFER_FILE:sarプロセス情報出力ファイル名
#       RETURNS:  ---  
#-------------------------------------------------------------------------------
resource_stop_server(){
   logger_debug "sarを停止"
   ssh -p ${3} ${1} "kill \`cat \"${2}/${SAR_PROCESS_INFO_BUFFER_FILE}\"\`"
   end_if_error $? "サーバ${1}におけるsarの停止に失敗しました"
   ssh -p ${3} ${1} "rm \"${2}/${SAR_PROCESS_INFO_BUFFER_FILE}\""
   end_if_warn $? "サーバ${1}におけるsarのpidファイルの削除に失敗しました"
}
