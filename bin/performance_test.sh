#!/bin/bash - 
#=============================================================================
#
#           FILE: performance_test.sh
#
#          USAGE: bash performance_test.sh
#
#    DESCRIPTION: 性能検証実行ファイル
#
# COPYRIGHT NOTE: Copyright(c) 2017 NTT Corporation.
#        CREATED: 2015年3月13日
#        UPDATED: 2017年12月18日
#        VERSION: 2.0.0
#
#============================================================================

set -o nounset                              # Treat unset variables as an error

# カレントをコマンドディレクトリに移動させる
command_dir=`dirname $0`
if [ $command_dir = '' ]; then
   command_dir=$(dirname $(which $0))
fi
cd $command_dir

. ../modules/main.sh  # 検証の開始
