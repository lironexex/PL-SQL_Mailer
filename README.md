# plsqltools

Send HTML mails with binary or text attachments from an oracle procedure.


Usage for mailer:

* Execute package in a schema.

* Set mail server in body. 
  I used a static server for it. 
  You can use a parameter for that too. Like `PK_MAILER.SET_SERVER('...');` etc

~~~ sql plsql
CREARE OR REPLACE PROCEDURE P_HTML_MAIL_TEST IS
 vBODY CLOB;
 vREPORTTEST CLOB;
 vTEST NUMBER(1);
BEGIN
  vBODY := '<html><head>';
  vBODY := vBODY || '<style>div {font-family:Calibri, Tahoma, Geneva, sans-serif; font-size:14px;}</style></head>';
  vBODY := vBODY || '<body><div>Hi <span style="font-weight:bold; color:#FF0000;">HTML</span> mail</div>';
  vBODY := vBODY || '<div> Report Date: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI') || '</div>';    
  vBODY := vBODY || '</body>'; 
  
  vREPORTTEST := '<h1>Same test file</h1>';
  
  PK_MAILER.BEGIN_MAIL(pSENDER => 'some_sender@mydomain.com', pCONTENTTYPE => 'text/html; "charset=utf-8"');
  PK_MAILER.SET_SUBJECT(pSUBJECT => 'Some Subject');
  PK_MAILER.ADD_TO('recipient_to1@test.com');
  PK_MAILER.ADD_TO('recipient_to2@test.com');
  PK_MAILER.ADD_CC('recipient_cc1@test.com');
  PK_MAILER.ADD_BCC('recipient_bcc1@test.com');
  PK_MAILER.SET_BODY(pBODY => vBODY); --Set Body 
  
  FOR PC IN (
       --Content Type is application/pdf, text/html etc. FileData is BLOB
       SELECT F.CONTENTTYPE, F.FILEDATA 
         FROM TFILES F
        WHERE F.FILETYPE = vTEST
  )
  LOOP
    PK_MAILER.ADD_BLOB_ATTACHMENT(pFILENAME => PC.FILENAME , pFILEDATA => PC.FILEDATA , pCONTENTTYPE => PC.FILETYPE);
  END LOOP;
  PK_MAILER.ADD_CLOB_ATTACHMENT(pFILENAME => 'Sample_Report.html', pFILEDATA => vREPORTTEST, pCONTENTTYPE => 'text/html');
  PK_MAILER.SEND;
END P_HTML_MAIL_TEST;
