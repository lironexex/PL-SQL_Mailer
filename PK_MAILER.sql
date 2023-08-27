CREATE OR REPLACE PACKAGE PK_MAILER AUTHID DEFINER IS
  /*************************************************************************************************************************/
  TYPE CLOBFILE_INFO IS RECORD(FILENAME VARCHAR2(200), FILEDATA CLOB, CONTENTTYPE VARCHAR2(50) DEFAULT 'text/plain;charset="utf-8"', 
                               INLINEFLG BOOLEAN DEFAULT FALSE);
  TYPE BLOBFILE_INFO IS RECORD(FILENAME VARCHAR2(200), FILEDATA BLOB, CONTENTTYPE VARCHAR2(50) DEFAULT 'application/octet-stream', 
                               INLINEFLG BOOLEAN DEFAULT FALSE);

  TYPE CLOB_ATTACHMENTS_TABLE IS TABLE OF CLOBFILE_INFO;
  TYPE BLOB_ATTACHMENTS_TABLE IS TABLE OF BLOBFILE_INFO;
  
  PROCEDURE PRINT_RECIPIENTS;
  FUNCTION TO_COUNT RETURN NUMBER;
  FUNCTION CC_COUNT RETURN NUMBER;
  FUNCTION BCC_COUNT RETURN NUMBER;
  PROCEDURE BEGIN_MAIL(pSENDER VARCHAR2, pREPLYTO VARCHAR2 DEFAULT NULL, pPRIORITY PLS_INTEGER DEFAULT 3, pCONTENTTYPE VARCHAR2 DEFAULT 'text/html;charset="iso-8859-9"');
  PROCEDURE ADD_TO(pEMAIL VARCHAR2);
  PROCEDURE ADD_CC(pEMAIL VARCHAR2);
  PROCEDURE ADD_BCC(pEMAIL VARCHAR2);
  PROCEDURE ADD_BLOB_ATTACHMENT(pFILENAME VARCHAR2, pFILEDATA BLOB, pCONTENTTYPE VARCHAR2 DEFAULT 'application/octet-stream', 
                                pINLINEFLG BOOLEAN DEFAULT FALSE);
  PROCEDURE ADD_CLOB_ATTACHMENT(pFILENAME VARCHAR2, pFILEDATA CLOB, pCONTENTTYPE VARCHAR2 DEFAULT 'text/plain;charset="utf-8"', 
                                pINLINEFLG BOOLEAN DEFAULT FALSE);
  PROCEDURE SET_SUBJECT(pSUBJECT VARCHAR2);
  PROCEDURE SET_BODY(pBODY CLOB);  
  PROCEDURE SEND;

END;

CREATE OR REPLACE PACKAGE BODY PK_MAILER IS
  
  
  TO_LIST DBMS_SQL.VARCHAR2_TABLE;
  CC_LIST DBMS_SQL.VARCHAR2_TABLE;
  BCC_LIST DBMS_SQL.VARCHAR2_TABLE;
  
  BLOB_ATTACHMENTS BLOB_ATTACHMENTS_TABLE;
  CLOB_ATTACHMENTS CLOB_ATTACHMENTS_TABLE;
  
  MAIL_CONN UTL_SMTP.CONNECTION;
  MAIL_HOST VARCHAR2(100) := 'myhost.mydomain.local';
  MAIL_HOST_PORT PLS_INTEGER := 25;  
  MAIL_SUBJECT VARCHAR2(500);
  MAIL_REPLYTO VARCHAR2(50);
  MAIL_PRIORITY PLS_INTEGER;
  MAIL_BODY CLOB;
  MAIL_SENDER VARCHAR2(50);
  MAIL_BODYCONTENTTYPE VARCHAR2(100) := 'text/html;charset="utf-8"';

  /*************************************************************************************************************************/
  --For Debugging purposes.
  PROCEDURE PRINT_RECIPIENTS IS
  BEGIN
   IF TO_LIST.COUNT > 0 THEN
     FOR i IN TO_LIST.FIRST .. TO_LIST.LAST
     LOOP
       DBMS_OUTPUT.PUT_LINE('TO  :' || TO_LIST(i) );
     END LOOP;
   END IF;
  
   IF CC_LIST.COUNT > 0 THEN
     FOR i IN CC_LIST.FIRST..CC_LIST.LAST
     LOOP
       DBMS_OUTPUT.PUT_LINE('CC  :' || CC_LIST(i) );
     END LOOP;
   END IF;

   IF BCC_LIST.COUNT > 0 THEN   
     FOR i IN BCC_LIST.FIRST..BCC_LIST.LAST
     LOOP
       DBMS_OUTPUT.PUT_LINE('BCC  :' || BCC_LIST(i) );
     END LOOP;
   END IF;   
  END PRINT_RECIPIENTS;
  /*************************************************************************************************************************/
  FUNCTION TO_COUNT RETURN NUMBER IS 
  BEGIN
    RETURN TO_LIST.COUNT;
  END TO_COUNT;
  /*************************************************************************************************************************/
  FUNCTION CC_COUNT RETURN NUMBER IS 
  BEGIN
    RETURN CC_LIST.COUNT;
  END CC_COUNT;
  /*************************************************************************************************************************/
  FUNCTION BCC_COUNT RETURN NUMBER IS 
  BEGIN
    RETURN BCC_LIST.COUNT;
  END BCC_COUNT;
  /*************************************************************************************************************************/
  PROCEDURE BEGIN_MAIL(pSENDER VARCHAR2, pREPLYTO VARCHAR2 DEFAULT NULL, pPRIORITY PLS_INTEGER DEFAULT 3, 
                       pCONTENTTYPE VARCHAR2 DEFAULT 'text/html;charset="utf-8"') IS
  BEGIN
    TO_LIST.DELETE;
    CC_LIST.DELETE;
    BCC_LIST.DELETE;
    
    BLOB_ATTACHMENTS := BLOB_ATTACHMENTS_TABLE();
    CLOB_ATTACHMENTS := CLOB_ATTACHMENTS_TABLE();
    
    MAIL_PRIORITY := pPRIORITY;
    MAIL_SENDER := pSENDER;
    MAIL_BODYCONTENTTYPE := pCONTENTTYPE;
    IF pREPLYTO IS NULL THEN
      MAIL_REPLYTO := pSENDER;
    ELSE
      MAIL_REPLYTO := pREPLYTO;
    END IF;

  END BEGIN_MAIL;
  /*************************************************************************************************************************/
  PROCEDURE ADD_TO(pEMAIL VARCHAR2) IS
  BEGIN
    IF pEMAIL IS NULL THEN
      RETURN;
    END IF;
    TO_LIST(TO_LIST.COUNT) := pEMAIL;
  END ADD_TO;
  /*************************************************************************************************************************/
  PROCEDURE ADD_CC(pEMAIL VARCHAR2) IS
  BEGIN
    IF pEMAIL IS NULL THEN
      RETURN;
    END IF;
    CC_LIST(CC_LIST.COUNT) := pEMAIL;
  END ADD_CC;
  /*************************************************************************************************************************/
  PROCEDURE ADD_BCC(pEMAIL VARCHAR2) IS
  BEGIN
    IF pEMAIL IS NULL THEN
      RETURN;
    END IF;
    BCC_LIST(BCC_LIST.COUNT) := pEMAIL;
  END ADD_BCC;
  /*************************************************************************************************************************/
  PROCEDURE ADD_BLOB_ATTACHMENT(pFILENAME VARCHAR2, pFILEDATA BLOB, pCONTENTTYPE VARCHAR2 DEFAULT 'application/octet-stream', 
                                pINLINEFLG BOOLEAN DEFAULT FALSE) IS
    blobattach BLOBFILE_INFO;
    vCOUNT PLS_INTEGER;
  BEGIN
    BLOB_ATTACHMENTS.EXTEND;
    vCOUNT := BLOB_ATTACHMENTS.COUNT;

    blobattach.FILENAME := pFILENAME;
    blobattach.FILEDATA := pFILEDATA;
    blobattach.CONTENTTYPE := pCONTENTTYPE;
    blobattach.INLINEFLG := pINLINEFLG;
    BLOB_ATTACHMENTS(vCOUNT) := blobattach;
  END ADD_BLOB_ATTACHMENT;
  /*************************************************************************************************************************/
  PROCEDURE ADD_CLOB_ATTACHMENT(pFILENAME VARCHAR2, pFILEDATA CLOB, pCONTENTTYPE VARCHAR2 DEFAULT 'text/plain;charset="utf-8"', 
                                pINLINEFLG BOOLEAN DEFAULT FALSE) IS
    clobattach CLOBFILE_INFO;
    vCOUNT PLS_INTEGER;
  BEGIN
    CLOB_ATTACHMENTS.EXTEND;
    vCOUNT := CLOB_ATTACHMENTS.COUNT;
    clobattach.FILENAME := pFILENAME;
    clobattach.FILEDATA := pFILEDATA;
    clobattach.CONTENTTYPE := pCONTENTTYPE;
    clobattach.INLINEFLG := pINLINEFLG;
    CLOB_ATTACHMENTS(vCOUNT) := clobattach;
  END ADD_CLOB_ATTACHMENT;
  /*************************************************************************************************************************/
  PROCEDURE SET_SUBJECT(pSUBJECT VARCHAR2) IS
  BEGIN
    MAIL_SUBJECT := pSUBJECT;
  END SET_SUBJECT;
  /*************************************************************************************************************************/
  PROCEDURE SET_BODY(pBODY CLOB) IS
  BEGIN
    MAIL_BODY := pBODY;
  END SET_BODY;
  /*************************************************************************************************************************/
  PROCEDURE WRITE_CLOB_ATTACHMENT(pBOUNDARY VARCHAR2, pFILENAME VARCHAR2, pFILEDATA CLOB, pCONTENTTYPE VARCHAR2, pINLINE BOOLEAN) IS
    vLEN INTEGER;
    vINDEX INTEGER;
  BEGIN
    --Begin Block
    UTL_SMTP.write_data(MAIL_CONN, '--' || pBOUNDARY || UTL_TCP.crlf);
    UTL_SMTP.write_data(MAIL_CONN, 'Content-Type: ' || pCONTENTTYPE || UTL_TCP.crlf);

    IF pFILENAME IS NOT NULL THEN
      IF pINLINE THEN
        UTL_SMTP.write_data(MAIL_CONN, 'Content-Disposition: inline; filename="' || pFILENAME || '"' || UTL_TCP.crlf);
      ELSE
        UTL_SMTP.write_data(MAIL_CONN, 'Content-Disposition: attachment; filename="' || pFILENAME || '"' || UTL_TCP.crlf);
      END IF;
    END IF;
    UTL_SMTP.write_data(MAIL_CONN, UTL_TCP.crlf);
    
    --Write Lob
    vLEN := DBMS_LOB.getlength(pFILEDATA);
    vINDEX := 1;
    WHILE vINDEX <= vLEN
    LOOP
      UTL_SMTP.write_raw_data(MAIL_CONN, UTL_RAW.CAST_TO_RAW(DBMS_LOB.SUBSTR(pFILEDATA, 32000, vINDEX)));
      vINDEX := vINDEX + 32000;
    END LOOP;
    
    --Finish Block
    UTL_SMTP.write_data(MAIL_CONN, UTL_TCP.crlf);
    
  END WRITE_CLOB_ATTACHMENT;
  /*************************************************************************************************************************/  
  PROCEDURE WRITE_BLOB_ATTACHMENT(pBOUNDARY VARCHAR2, pFILENAME VARCHAR2, pFILEDATA BLOB, pCONTENTTYPE VARCHAR2, pINLINE BOOLEAN) IS
    vLEN INTEGER;
    vINDEX INTEGER;
    vCHUNK RAW(32767);
  BEGIN
    UTL_SMTP.write_data(MAIL_CONN, '--' || pBOUNDARY || UTL_TCP.crlf);
    UTL_SMTP.write_data(MAIL_CONN, 'Content-Type: ' || pCONTENTTYPE || UTL_TCP.crlf);
    UTL_SMTP.write_data(MAIL_CONN, 'Content-Transfer-Encoding: base64' || UTL_TCP.crlf);

    IF pFILENAME IS NOT NULL THEN
      IF pINLINE THEN
        UTL_SMTP.write_data(MAIL_CONN, 'Content-Disposition: inline; filename="' || pFILENAME || '"' || UTL_TCP.crlf);
      ELSE
        UTL_SMTP.write_data(MAIL_CONN, 'Content-Disposition: attachment; filename="' || pFILENAME || '"' || UTL_TCP.crlf);
      END IF;
    END IF;
    UTL_SMTP.write_data(MAIL_CONN, UTL_TCP.crlf);


    vLEN := DBMS_LOB.getlength(pFILEDATA);
    vINDEX := 1;

    WHILE vINDEX <= vLEN
    LOOP
      vCHUNK := DBMS_LOB.SUBSTR(pFILEDATA, 57, vINDEX);
      vINDEX := vINDEX + 57;
      UTL_SMTP.write_data(MAIL_CONN, UTL_RAW.cast_to_varchar2(UTL_ENCODE.base64_encode(vCHUNK)));
    END LOOP;
    
    UTL_SMTP.write_data(MAIL_CONN, UTL_TCP.crlf);
  END WRITE_BLOB_ATTACHMENT;
  /*************************************************************************************************************************/
  PROCEDURE SEND IS
    vBOUNDARY VARCHAR2(32) := RAWTOHEX(SYS_GUID()); --Boundry seperator for contents
    vLEN INTEGER;
    vINDEX INTEGER;
    vERRORMSG VARCHAR2(2000);
  BEGIN
    
   
    MAIL_CONN := UTL_SMTP.open_connection(MAIL_HOST, MAIL_HOST_PORT);
    UTL_SMTP.ehlo(MAIL_CONN, MAIL_HOST);
    UTL_SMTP.mail(MAIL_CONN, MAIL_SENDER);

    IF TO_LIST.COUNT > 0 THEN
      FOR i IN TO_LIST.FIRST .. TO_LIST.LAST
      LOOP
        UTL_SMTP.rcpt(MAIL_CONN, TO_LIST(i));
      END LOOP;
    END IF;

    IF CC_LIST.COUNT > 0 THEN
      FOR i IN CC_LIST.FIRST..CC_LIST.LAST
      LOOP
        UTL_SMTP.rcpt(MAIL_CONN, CC_LIST(i));
      END LOOP;
    END IF;       

    IF BCC_LIST.COUNT > 0 THEN
      FOR i IN BCC_LIST.FIRST..BCC_LIST.LAST
      LOOP
        UTL_SMTP.rcpt(MAIL_CONN, BCC_LIST(i));
      END LOOP;
    END IF;
      
    UTL_SMTP.open_data(MAIL_CONN);
    UTL_SMTP.write_data(MAIL_CONN, 'Date: ' || TO_CHAR(SYSTIMESTAMP, 'Dy, DD Mon YYYY HH24:MI:SS TZHTZM', 'NLS_DATE_LANGUAGE=ENGLISH') || utl_tcp.crlf);
    UTL_SMTP.write_data(MAIL_CONN, 'From: ' || MAIL_SENDER || UTL_TCP.crlf);
    
    IF TO_LIST.COUNT > 0 THEN
      FOR i IN TO_LIST.FIRST .. TO_LIST.LAST
      LOOP
        UTL_SMTP.write_data(MAIL_CONN, 'To: ' || TO_LIST(i) || UTL_TCP.crlf);
      END LOOP;
    END IF;

    IF CC_LIST.COUNT > 0 THEN
      FOR i IN CC_LIST.FIRST..CC_LIST.LAST
      LOOP
        UTL_SMTP.write_data(MAIL_CONN, 'CC: ' || CC_LIST(i) || UTL_TCP.crlf);
      END LOOP;
    END IF;       
    
    IF BCC_LIST.COUNT > 0 THEN
      FOR i IN BCC_LIST.FIRST..BCC_LIST.LAST
      LOOP
        UTL_SMTP.write_data(MAIL_CONN, 'BCC: ' || BCC_LIST(i) || UTL_TCP.crlf);
      END LOOP;
    END IF;

    UTL_SMTP.write_data(MAIL_CONN, 'Subject: ' || MAIL_SUBJECT || UTL_TCP.crlf);
    UTL_SMTP.write_data(MAIL_CONN, 'Reply-To: ' || MAIL_SENDER || UTL_TCP.crlf);
    UTL_SMTP.write_data(MAIL_CONN, 'MIME-Version: 1.0' || UTL_TCP.crlf);
    UTL_SMTP.write_data(MAIL_CONN, 'Content-Type: multipart/mixed; boundary="' || vBOUNDARY || '"' || UTL_TCP.crlf || UTL_TCP.crlf);
    UTL_SMTP.write_data(MAIL_CONN, 'This is a multi-part message in MIME format.' || UTL_TCP.crlf);
    UTL_SMTP.write_data(MAIL_CONN, '--' || vBOUNDARY || UTL_TCP.crlf);
    UTL_SMTP.write_data(MAIL_CONN, 'Content-Type: ' || MAIL_BODYCONTENTTYPE || UTL_TCP.crlf || UTL_TCP.crlf);
   
    --BEGIN Write Mail Body
    
    vLEN := DBMS_LOB.getlength(MAIL_BODY);
    vINDEX := 1;
    WHILE vINDEX <= vLEN --Splitting to 32.000 bytes of chunk to prevent limit.
    LOOP
      UTL_SMTP.write_raw_data(MAIL_CONN, UTL_RAW.CAST_TO_RAW(DBMS_LOB.SUBSTR(MAIL_BODY, 32000, vINDEX)));
      vINDEX := vINDEX + 32000;
    END LOOP;
    UTL_SMTP.write_data(MAIL_CONN, UTL_TCP.crlf);
    --END Write Mail Body   
    
    
    IF CLOB_ATTACHMENTS.COUNT > 0 THEN
      FOR i IN CLOB_ATTACHMENTS.FIRST..CLOB_ATTACHMENTS.LAST
      LOOP
        WRITE_CLOB_ATTACHMENT(vBOUNDARY, CLOB_ATTACHMENTS(i).FILENAME, CLOB_ATTACHMENTS(i).FILEDATA, 
                              CLOB_ATTACHMENTS(i).CONTENTTYPE, CLOB_ATTACHMENTS(i).INLINEFLG);
      END LOOP;
    END IF;  
    
    IF BLOB_ATTACHMENTS.COUNT > 0 THEN
      FOR i IN BLOB_ATTACHMENTS.FIRST..BLOB_ATTACHMENTS.LAST
      LOOP
        WRITE_BLOB_ATTACHMENT(vBOUNDARY, BLOB_ATTACHMENTS(i).FILENAME, BLOB_ATTACHMENTS(i).FILEDATA, 
                              BLOB_ATTACHMENTS(i).CONTENTTYPE, BLOB_ATTACHMENTS(i).INLINEFLG);
      END LOOP;
    END IF;

    UTL_SMTP.write_data(MAIL_CONN, '--' || vBOUNDARY || '--' || UTL_TCP.crlf);
    utl_smtp.close_data(MAIL_CONN);
    utl_smtp.quit(MAIL_CONN);
    
    EXCEPTION
      WHEN OTHERS THEN
        --Some logging here.
        RAISE;
  END SEND;
  /*************************************************************************************************************************/
END;
