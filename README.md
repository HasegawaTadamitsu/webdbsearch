webdbsearch
===========

OCI8を用いて任意のSELECT文を発行し、WEB上で見やすく表示するツールです。

## Description
  OCI8を用いて任意のSELECT文を発行し、WEB上で見やすく表示するツールです。
日本語項目名、コードの変換、縦表示、横表示、印書用の表示など業務上に
検証物の事前検証などに使用することを目的としています。

  Oracleへの接続文字列、日本語項目名、コードのの変換テーブルは
ソースを書き換える必要があります。（が、見ての通りとっても簡単です)

  なおこのツールは、全く持てセキュリティなど考えていません。
データの破損、XSSなどあらゆる脅威に対し、なにも考えていません。
いかなる問題が発生しようとも、私には一切の責任を問わないものとするものとし、
自己判断にてご使用ください。

## Requirement

see Gemfile

## Usage

- webdbsearch.rb の設定。接続文字列。

  DBConnectMgr クラスの@connect_info を編集してください。
:PASSWORDがなければ、IDと同じです。(え？）

- webdbsearch.rb の設定。日本語コラム名、コードテーブル

  Schema クラスの@jp_cols_name,@code を編集してください。

- 起動

$ ruby webdbsearch.rb
として、起動します。

- http://127.0.0.1:4567/ にアクセスしてください。

- 接続文字列の選択、SQLの入力、及び、'送信(横max size)',

  '送信(横limit size)','送信(縦)'を押してください。

  '送信(横max size)'は、横幅を無視して、1レコード1行に表示し、50行単位にtableを作ります。

  '送信(横limit size)'は、cursolから取得した文字数もどきの割合に応じて、
一定の横幅になるように1レコードを複数tableにて表示します。
印刷時なるべく多くの情報を一枚に詰め込むことを目的としています。

 '送信(縦)'は、1レコードを1テーブルで縦表示します。


## Install
  展開しそのまま実行してください。

## etc
  利用の際は感想等メールにてご連絡を頂けると励みになります。

## Licence
  This software is released under the MIT License, 

## Author
  Hasegawa.tadamitsu@gmail.com

