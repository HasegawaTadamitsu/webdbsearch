#!/bin/sh

. ./oracle.env
rm /tmp/sql.txt
for i in `seq 1001 `; do

  echo "INSERT INTO WEBDBSEARCH (dnum5,DCHAR32, DVCHAR256, DNUMBER32, DNUMBER10_1, DDATE,DM1_CD,DM2_CD) VALUES ($i,'char', 'vchar', '1234567890123', '123.1', sysdate,'01','99') ;" >> /tmp/sql.txt

  echo "insert into webdbsearch2 values ($i,'dc32','dv256',10, 10.1, sysdate, '1','1','1','1','1','1','1','1','1');" >> /tmp/sql.txt

done



exec_sql <<EOF
WHENEVER SQLERROR CONTINUE NONE
DROP TABLE webdbsearch CASCADE CONSTRAINTS;
EOF

exec_sql <<EOF
WHENEVER SQLERROR CONTINUE NONE
DROP TABLE webdbsearch2 CASCADE CONSTRAINTS;
EOF

exec_sql <<EOF
create table  webdbsearch
(
  dnum5      number(5,0),
  dchar32    char(32),
  dvchar256  varchar2(256),
  dblob    blob,
  dnumber32   NUMBER(32,0), 
  dnumber10_1  NUMBER(10,1),
  ddate    date,
  DM1_CD    char(2),
  DM2_CD    char(2)
)
NOLOGGING
;

create table  webdbsearch2
(
  dnum5      number(5,0),
  dchar32    char(32),
  dvchar256  varchar2(256),
  dnumber32   NUMBER(32,0), 
  dnumber10_1  NUMBER(10,1),
  ddate    date,
  DM1_CD    char(2),
  DM2_CD    char(2),
  DM3_CD    char(2),
  DM4_CD    char(2),
  DM5_CD    char(2),
  DM6_CD    char(2),
  DM7_CD    char(2),
  DM8_CD    char(2),
  dvchar10  varchar2(10)
)
NOLOGGING
;

purge recyclebin;
show recyclebin

desc webdbsearch

@/tmp/sql.txt
commit;
select count(*) from webdbsearch;
quit

EOF

