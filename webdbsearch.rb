# coding: utf-8

## Copyright (c) 2014 Hasegawa.Tadamitsu
## This software is released under the MIT License.
## http://opensource.org/licenses/mit-license.php

require 'sinatra'
require 'sinatra/reloader'
require 'haml'
require 'singleton'
require 'logger'
require 'oci8'
require 'pry'


class Exception
  def backtrace_to_html
    trace = self.backtrace
    sanitized_trace = trace.map do |val| 
      val.gsub /[<|>]/, ""
    end

    ret = sanitized_trace.join "<br>\n"
    return ret
  end
end

class Integer
  def jpy_comma
    self.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
  end
end

class MyLogger
  include Singleton
  attr_reader :logger

  def initialize
    STDOUT.sync = true
    STDERR.sync = true
    @logger = Logger.new STDOUT
  end

end

class DBConnectMgr
  include Singleton

  def initialize
    con_str_sky = 'sky/XE'
    @connect_info = {
       'hasegawa@sky/XE'  => {:ID=>'hasegawa',  :CONNECT_STR=>con_str_sky},
       'hasegawa2@sky/XE' => {:ID=>'hasegawa2', :CONNECT_STR=>con_str_sky},
       'hasegawa3@sky/XE' => {:ID=>'hasegawa3', :CONNECT_STR=>con_str_sky,
                              :PASSWORD =>"aaa"}

    }
  end

  def connect_info_to_html key
    connect_info = @connect_info[key]
    return "no infomation" if connect_info == nil
    return to_print_str connect_info
  end

  def connect_info_to_select_html  name, default_key=''
    ret =""
    ret += "<select name='#{name}'>\n"
    @connect_info.each do |key,value|
      selected = (default_key == key) ? 'selected':''
      ret += "  <option value='#{key}' #{selected}>"
      ret += to_print_str value
      ret += "</option>\n"
    end
    ret += "</select>\n"
    return ret
  end

  def execute_sql connect_key,sql
    connect_info = @connect_info[connect_key]
    user_id = connect_info[:ID]
    password = connect_info[:PASSWORD]
    password = user_id if password == nil
    connect_str = connect_info[:CONNECT_STR]

    begin
      connect = OCI8.new(user_id, password, connect_str)
    rescue => e
      str = to_print_str connect_info
      MyLogger.instance.logger.info "raise:#{e},#{str},#{password}"
      raise e
    end
    begin
      cursor = connect.parse sql
      count =  cursor.exec
      MyLogger.instance.logger.info "exec SQL.#{sql}."
      yield cursor
    ensure
      cursor.close
      connect.logoff if connect != nil
    end
  end

  private
  def to_print_str connect_info
    return "#{connect_info[:ID]} @ #{connect_info[:CONNECT_STR]}"
  end
end

class Schema
  include Singleton
  def init
    @jp_cols_name = { 'TABLE_NAME' =>"テーブルネーム",
                      'INSTANCES' =>"インスタンス",
                      'SRV' => "サーバ" }
    @code ={
           'DM1_CD' =>{'01' =>"正しいコード",
                       '12' =>"なんでだろう"},
           'DM2_CD' =>{'XX' =>"え？"}
           }
  end

  def cols_to_html name
    jp_name = @jp_cols_name[name]
    return name if jp_name == nil or jp_name ==""
    return name + "<br>" + jp_name    
  end 

  def code_col_to_html col_meta,value
    return "(nil)" if value == nil
    case col_meta.data_type
    when :date
      return value.strftime("%Y%m%d %H%M%S")
    when :number
      return value.jpy_comma if col_meta.scale == 0 and value.kind_of? Integer
      return value
    when :blob
      return "blob"
    when :varchar2
      return value
    when :long
      return value
    when :char
      name = col_meta.name
      code  = @code[name]
      return value  if code == nil
      code_val = code[value]
      return value.to_s + ":(unknown code)" if code_val == nil
      return value.to_s + ":" + code_val
    else
      raise "unknown type #{col_meta.data_type}"
    end 
  end
end

helpers do

#サイズモード時の横幅
SIZE_MODE_WIDTH = 900

# 1文字(char)あたりのpx
TO_PX_PER_CHAR = 9

  def max_size_convert arg_cursol
    byte_lengths = Array.new
    arg_cursol.column_metadata.each do |type|
       case type.data_type
       when :char
         val = type.data_size
         val = 10 if val < 10
         byte_lengths.push val

       when :number
          if type.scale <= 0 and type.precision <= 0
            byte_lengths.push 38
            next
          end
          val = type.precision
          if type.scale != 0
            val +=  type.scale + 3 # hmm
          else
            val +=  type.precision % 3 # commna
          end
          byte_lengths.push val
       when :date
          byte_lengths.push 15 # YYYYMMDD HHMMSS => 15 char
       when :varchar2
          val = type.data_size
          byte_lengths.push val
       when :blob
          byte_lengths.push 1 #
       end
    end

    byte_lengths = byte_lengths.map do |val| 
      ( SIZE_MODE_WIDTH < val * TO_PX_PER_CHAR) ? \
                  (SIZE_MODE_WIDTH) :( val * TO_PX_PER_CHAR)
    end

    result = Array.new
    now_width = 0
    tmp_length = Array.new
    byte_lengths.each do |val|
      now_width += val
      if SIZE_MODE_WIDTH < now_width and tmp_length.size != 0
        result.push tmp_length
        now_width = val
        tmp_length = Array.new
      end
      tmp_length.push val
    end
    result.push tmp_length
    return result
  end

  def align arg_cursol
    aligns = Array.new
    arg_cursol.column_metadata.each do |type|
       case type.data_type
       when :char
          aligns.push "left"
       when :varchar2
           aligns.push "left"
       when :number
           aligns.push "right"
       when :date
           aligns.push "center"
       else
           aligns.push "center"
       end
    end
    return aligns
  end

end

configure do
  set :show_exceptions, false 
  mime_type :sql,'text/plain'
  MyLogger.instance.logger.debug 'logger start'
  Schema.instance.init
end

# 最大データ件数。この件数より検索結果が多いと、無視します。
MAX_COUNT = 1100

#横表示モード時の1テーブルあたりの行数
#横表示モード時、MAX_COUNT件数の行数を持つテーブルを作成すると遅いので
#この単位にテーブルをわけます。
MAX_LINE_COUNT_PER_TABLE = 50


get '/' do
  @connect_key = params[:CONNECT_INFO]
  @sql = params[:SQL]
  @disp_mode = nil

  MyLogger.instance.logger.info "#{@connect_key},#{@sql}"

  if @connect_key == nil or @connect_key =="" or @sql == nil or @sql == ""
    MyLogger.instance.logger.info "no connect_key(first access?)"
    return haml :index_page
  end

  unless @sql.downcase.start_with? "select " 
    MyLogger.instance.logger.info "bad sql."
    @msg = "SQLはSELECT で始まっている必要があります。"
    return haml :index_page
  end

  if  params[:TATE]   != nil and  params[:TATE]  != ""
    @disp_mode = :TATE
  elsif params[:SIZE] != nil and params[:SIZE] != ""
    @disp_mode = :SIZE
  elsif params[:YOKO] != nil and params[:YOKO] != ""
    @disp_mode = :YOKO
  end

  MyLogger.instance.logger.info "disp_mode #{@disp_mode}"

  DBConnectMgr.instance.execute_sql @connect_key,@sql  do |cur|
    cur.prefetch_rows = MAX_COUNT

    @cols_name = cur.getColNames.map do | name |
       Schema.instance.cols_to_html name
    end

    if @disp_mode == :SIZE
      @convert_info = max_size_convert cur
    end

    @align_info = align cur

    @datas = Array.new
    co = 0 
    while line_data = cur.fetch
      co += 1
      raise "Over max count.#{MAX_COUNT}." if MAX_COUNT < co
      line_data_to_html = Array.new
      line_data.each_with_index do | data ,i|
         col_meta =  cur.column_metadata[i]
         val = Schema.instance.code_col_to_html col_meta, data
         line_data_to_html.push val
      end
      @datas.push line_data_to_html
    end
  end

  haml :index_page
end

error do |e|
  status 500
  @exception = e
  haml :error_page
end


__END__
@@ layout
!!! 5
%html
  %header

  %body
    %div.title
      %h1 WEBDBSearch
    %div.body
      = yield
    %div.footer
      %hr
      create time at 
      = Time.now
      %br
      connect info 
      = DBConnectMgr.instance.connect_info_to_html @connect_key
      %br
      %a{ :href=>"/"} index pageに戻る
      %a{ :href=>"javascript:history.back();" }  一つ前に戻る

@@ error_page
%div.msg
  %strong
    = @exception.message

%div.main_body
  %a{ :href=>"/"} index pageに戻る
  %a{ :href=>"javascript:history.back();" }  一つ前に戻る
  %br
  %hr
  %h2 トレース情報
  =  @exception.backtrace_to_html


@@ index_page
%div.msg
  %strong
    = @msg

%div.main_body#top
  %form{ :action=>'/'}
    = DBConnectMgr.instance.connect_info_to_select_html 'CONNECT_INFO', @connect_key
    %br
    SQL
    %input{ :type=>"text", :size=>100, :value=>"#{@sql}",:name=>'SQL'}
    %br
    %input{ :type=>"submit", :value=>"送信(横max size)", :name=>'YOKO'}
    %input{ :type=>"submit", :value=>"送信(横limit size)", :name=>'SIZE'}
    %input{ :type=>"submit", :value=>"送信(縦)", :name=>'TATE'}
  %hr
    %p SQL
    = @sql
  %hr
    - case @disp_mode
    - when :YOKO
      result count
      = @datas.size
      - max_block_co = @datas.size / MAX_LINE_COUNT_PER_TABLE + 1 
      - max_block_co.times do |block_co|
        - target_datas = @datas[(block_co*MAX_LINE_COUNT_PER_TABLE)..-1]
        - break if target_datas.size == 0
        %div{ :id=> "block_no_#{block_co}"} 
          %div{ :style=>"text-align: right"}
            - if block_co != 0 
              %a{ :href=>"#block_no_#{block_co-1}"} Previous block
            - else
              %a{ :disabled=>"disabled" } Previous block
            %a{ :href=>"#top"}  page top
            - if block_co + 1 != max_block_co
              %a{ :href=>"#block_no_#{block_co+1}"} Next block
            - else
              %a{ :class=>"disabled" } Next block

          %table{:border=>1}
            %tr
              %th No
              - @cols_name.each do | col |
                %th
                  = col
            - target_datas.each.with_index 1  do | data,i |
              - break if MAX_LINE_COUNT_PER_TABLE < i
              %tr
                %td{ :style => "text-align: right" } 
                  = "#{i+(block_co*MAX_LINE_COUNT_PER_TABLE)}/#{@datas.size}"
                - data.each_with_index do |val,j|
                  %td{ :style => "text-align: #{@align_info[j]}" }
                    = val
          %br
    - when :TATE
      - @datas.each.with_index 1  do | data, i |
        %div{ :id=>"block_no_#{i}", :style=>"page-break-inside:avoid;"}
          %div{ :style=>"text-align: right"}
            - if i != 1 
              %a{ :href=>"#block_no_#{i-1}"} Previous block
            - else
              %a{ :class=>"disabled" } Previous block
            %a{ :href=>"#top"}  page top
            - if i + 1 <= @datas.size
              %a{ :href=>"#block_no_#{i + 1}"} Next block
            - else
              %a{ :class=>"disabled" } Next block

          %table{:border=>1}
            %tr
              %th No
              %td{ :style => "text-align: right" } 
                = "#{i}/#{@datas.size}"
            - data.each_with_index do |val,x|
              %tr
                %th
                  = @cols_name[x]
                %td{ :style => "text-align: #{@align_info[x]}" }
                  = val
          %br
    - when  :SIZE
      - @datas.each.with_index 1  do | data, i |
        %div{ :id=>"block_no_#{i}", :style=>"page-break-inside:avoid;"}
          %div{ :style=>"text-align: right"}
            - if i != 1 
              %a{ :href=>"#block_no_#{i-1}"} Previous block
            - else
              %a{ :class=>"disabled" } Previous block
            %a{ :href=>"#top"}  page top
            - if   i + 1 <= @datas.size
              %a{ :href=>"#block_no_#{i + 1}"} Next block
            - else
              %a{ :class=>"disabled" } Next block
          No
          = "#{i}/#{@datas.size}"
          - x = 0
          - @convert_info.each do |conv|
            %table{:border=>"1px",:style=>"table-layout:fixed;"}
              %tr
                - @cols_name[x...(x + conv.size)].each.with_index do | col,xx |
                  %th{:style=>"width:#{conv[xx]}px;word-break:break-all;font-size:x-small;" }
                    = col
              %tr
                - data[x...(x + conv.size)].each_with_index do |da,xx|
                  %td{ :style => "text-align:#{@align_info[x+xx]};width:#{conv[xx]}px;word-break:break-all;" }
                    = da
              - x += conv.size
