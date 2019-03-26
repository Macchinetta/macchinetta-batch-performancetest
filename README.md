macchinetta-batch-performance-test
===============

# 検証資材実行手順
## 0. 前提
本手順は、ATRS-batchおよび、「サンプルアプリケーション(ATRS-batch)マニュアル」(利用マニュアル)の内容を把握していることを前提とします。
ATRS-batchの資材や利用マニュアルに記載されている内容については説明を省略します。

※ 本手順で記載しているディレクトリ中のバージョンや「xxx」については適宜読み替えてください。

## 1. 実行環境
実行環境で利用するOS・ソフトウェアは以下の通りです。

* OS : CentOS Linux (release 7.4.1708)
* JDK : OpenJDK (1.8.0_151)
* RDBMS : PostgreSQL (9.6.5)
* Build Tool : Apache maven (3.3.9)

※ ()内は動作確認時のバージョンを表します。

システム構成は利用マニュアルの「5.2 システム構成」を参照してください。

## 2. 事前準備
### 2.1. 資材配備
以下の資材をバッチサーバ上の任意のディレクトリに配備します。

* atrs-batch
  * ATRS-batchのプロジェクト
* macchinetta-batch-performance-test
  * AP検証資材(※)

~~~
※ 動作確認を実施するにあたり、以下コメントアウトして実施しております。

1. modules/collect_func.sh (copy_db_log内)
　ssh -p ${DB_SSH_PORT} ${DB_MASTER_NAME}@${DB_IPADDRESS} "source ${DB_PATH_SOURCE_FILE_PATH};pg_ctl -D ${DB_CLUSTER_LOCATION} stop"
　⇒ DBサーバ停止後、バックアップファイルからDBクラスタを展開しているが、バックアップファイルが無くDBクラスタを作成できないためDBサーバは停止しない

2. modules/collect_func.sh (copy_db_log内)
　end_if_error $? "サーバ${DB_IPADDRESS}におけるDBサーバの停止に失敗しました"
　⇒ 1.でDBサーバの停止を行わなくなるためコメントアウトする。

3. modules/main_func.sh (init_db_condition内)
　check_db                               # DBの動作状態確認
　⇒ 1.でDBサーバ停止を行わなくなり、check_dbを実行するとエラーとなってしまうためコメントアウトする。

4. modules/main_func.sh (init_db_condition内)
　clear_db                               # DB初期化
　⇒ 1.のとおり、DBクラスタのバックアップファイルが無く、初期化できないためコメントアウトする。

5. modules/main_func.sh (collect_result内)
　move_local "${HEAPSTATS_PATH}" "${1}"                           # HeapStats情報ファイル
　⇒ 該当ファイル（HeapStats情報ファイル）が存在しない＆作成箇所も見当たらないためコメントアウトする

6. modules/main_func.sh (collect_result内)
　move_local "${GC_PATH}" "${1}"                           # GCログ
　⇒ 該当ファイル（GCログ）が存在しない＆作成箇所も見当たらないためコメントアウトする
~~~

### 2.2. 検証データ配備
検証に必要なデータを配備します。

※ 動作確認時はATRSサンプルアプリケーションに同梱のデータを利用しています。

検証目的に応じて、データ量の異なる検証データ(3パターンまで対応)を用意します。
用意する検証データのパターン数に応じて、「3.2. 起動オプションの変更」でデータ量番号を適宜設定してください。

配備する検証データは以下の通りです。

#### 2.2.1 SQL
* DDL/DML  
atrs-batch/sql/postgresディレクトリ配下に必要に応じてsize1~size3のディレクトリを作成し
作成したディレクトリ配下にそれぞれ以下のSQLを配備します。
 * 00000_drop_all_tables.sql
 * 00100_create_all_tables.sql
 * 00200_insert_fixed_value.sql
 * 00210_insert_route.sql
 * 00220_insert_flight_master.sql
 * 00230_insert_member.sql
 * 00240_insert_peak_time.sql
 * 00250_insert_flight.sql
 * 00260_insert_reservation.sql

~~~
(例) データ量の異なるデータをを2パターン用意する場合
atrs-batch/sql/postgres/
                 ├ size1/
                 │   ├ 00000_drop_all_tables.sql
                 │   ├ …
                 │   └ 00260_insert_reservation.sql
                 └ size2/
                     ├ 00000_drop_all_tables.sql
                     ├ …
                     └ 00260_insert_reservation.sql
~~~

* 非同期実行用SQL  
atrs-batch/sql/postgresディレクトリ配下に
非同期実行の際にジョブ要求テーブルにレコードを挿入するinsert_job_data.sqlを配備します。

#### 2.2.2 FILE
atrs-batch/inputOrgディレクトリ配下に必要に応じてデータ量の異なるフライト情報更新ファイルを
FlightUpdate_size1.csv~FlightUpdate_size3.csvのファイル名で配備します。

~~~
(例) データ量の異なるデータをを2パターン用意する場合
atrs-batch/inputOrg
             ├ FlightUpdate_size1.csv
             └ FlightUpdate_size2.csv
~~~

### 2.3. 環境差分情報の編集
以下の環境差分情報を実行環境に合わせて変更します。

* atrs-batch/src/main/resources/batch-application.properties
  * admin.jdbc.url
  * admin.jdbc.username
  * admin.jdbc.password
  * jdbc.url
  * jdbc.username
  * jdbc.password
* atrs-batch/scripts/aggregateReservation.bat  
※aggregateReservation.shも同様
  * DB_HOSTNAME (DBサーバのIPアドレス)
* macchinetta-batch-performance-test/conf/condition.sh
  * DB_IPADDRESS (DBサーバのIPアドレス)
  * TEST_LOCATION (検証資材ディレクトリパス)
  * SAMPLE_AP_LOCATION (サンプルアプリケーションのディレクトリパス)
  * ACTION_LOG_LOCATION (サンプルアプリケーション動作ログのファイルパス)
  * DB_SSH_PORT (DBサーバへSSH接続する際の指定ポート番号)
  * LOCAL_SSH_PORT (ローカルサーバへSSH接続する際の指定ポート番号)
  * DB_PSQL_PORT (DBサーバへpsql接続する際の指定ポート番号)

### 2.4. ATRSサンプルバッチアプリケーションのビルド
atrs-batchの格納ディレクトリに移動し、以下のコマンドを実行します。

~~~
$ cd xxx/atrs-batch
$ mvn clean dependency:copy-dependencies -DoutputDirectory=lib package
~~~

「BUILD SUCCESS」となることを確認してください。

targetディレクトリにatrs-batchのjarが出力されるため、このjarファイルをlibディレクトリにコピーします。

~~~
$ cp ./target/atrs-batch-[バージョン].jar ./lib
~~~


### 2.5. データベースの構築
データベースを構築します。

#### 2.5.1 DBサーバ起動
DBサーバ上で以下のコマンドを実行し、PostgreSQLを起動します。

~~~
$ pg_ctl -w -D /var/lib/pgsql/9.6/pg_cluster start
~~~

以下のコマンドで起動されたことを確認してください。
~~~
$ pg_ctl -D /var/lib/pgsql/9.6/pg_cluster status
~~~

コマンド実行結果サンプル
~~~
$ pg_ctl -w -D /var/lib/pgsql/9.6/pg_cluster start
サーバの起動完了を待っています....< 2017-11-30 16:48:56.489 JST > LOG:  ログ出力をログ収集プロセスにリダイレクトしています
< 2017-11-30 16:48:56.489 JST > ヒント:  ここからのログ出力はディレクトリ"pg_log"に現れます。
完了
サーバ起動完了

$ pg_ctl -D /var/lib/pgsql/9.6/pg_cluster status
pg_ctl: サーバが動作中です(PID: 7524)
/usr/pgsql-9.6/bin/postgres "-D" "/var/lib/pgsql/9.6/pg_cluster"
~~~

#### 2.5.2 psql起動
以下のコマンドでpsqlを起動します。

~~~
$ psql -U [ユーザID]
~~~
パスワードを入力します。

#### 2.5.3 データベース作成
以下のSQLでデータベースを作成します。

~~~
# create database atrs_batch with encoding = 'UTF8';
~~~

#### 2.5.4 psql終了
「\q」を入力し、psqlを終了します。

### 2.6. DB接続確認
以下のコマンドを実行し、DBに接続できることを確認します。

~~~
$ psql -p [ポート番号] -h [ホスト名] -U [ユーザID] -d [データベース名] -c 'SELECT 1'
~~~
パスワードを入力します。

※ ポート番号および、ホスト名はバッチサーバとDBサーバが別サーバ構成となっている場合に指定してください。（同一サーバの場合は不要です）

実行結果サンプル
~~~
# psql -p 12722 -h 10.0.2.2 -U postgres -d atrs_batch -c 'SELECT 1'
?column?
----------
       1
(1 行)
~~~

※ DBサーバとバッチサーバが別サーバ構成の場合に接続確認が出来ない場合は、DBサーバ側のアクセス権限等をご確認ください。

## 3. 検証スクリプト実行
検証スクリプトを実行します。

### 3.1. 検証資材格納ディレクトリに移動
検証資材の格納ディレクトリに移動します。

~~~
$ cd xxx/macchinetta-batch-performance-test
~~~

### 3.2. 起動オプションの変更
起動オプションで検証種別、データ量番号、試行回数を変更できます。

検証目的に応じて、以下の値をスクリプト内に記載の設定例を参考に適宜変更してください。

* conf\condition.sh
  * TEST_KIND (検証種別)
  * TEST_DATA_AMOUNT (データ量番号)
  * TEST_TIME (試行回数)

※ 動作確認時はATRSサンプルアプリケーションに同梱のデータを利用しているため、データ量番号=("1")、試行回数=1で実施しております

### 3.3. 検証スクリプト実行
以下のコマンドを実行して検証を開始します。

~~~
$ bash bin/performance_test.sh
~~~

## 4. 実行結果確認
検証スクリプトの実行結果を確認します。

conf\condition.shのRESULT_LOCATIONに指定したディレクトリにログが出力されていることを確認します。

* ログディレクトリ名
  * testYYYYMMDDHHmmss
    配下に「1_1_1_1」～「27_3_3_3」の名称で検証回次ごとのディレクトリが存在し、各ディレクトリにatrs-batch-application.logなどのログファイルが出力されていること
