USE [Plexus]
GO

/* BEFORE YOU ANALYZE THE CODE READ BELOW

The seciton of code below is for updating an existing TLN account on plexus,

*/
  /*Declaring a cursor*/
  DECLARE @ExistingLiveAccounts CURSOR;

  /*Cursor variables*/
 DECLARE @MPM_TLN_ACCT_NO VARCHAR(50)
 DECLARE @Status VARCHAR(50)
 DECLARE @CUST_NO VARCHAR(50)
 DECLARE @PRODUCT VARCHAR(50)
 DECLARE @DDA_ACCOUNT_NO VARCHAR(50)
 DECLARE @DDA_SUB_PROD_CDE VARCHAR(50) 
 DECLARE @TLN_TAKE_UP_DATE VARCHAR(50)
 DECLARE @TLN_LOAN_VALUE VARCHAR(50)
 DECLARE @TLN_INIT_FEE VARCHAR(50)
 DECLARE @TLN_TOTAL_AMT VARCHAR(50)
 DECLARE @AMT_REPAID VARCHAR(50)
 DECLARE @ARREARS VARCHAR(50)
 DECLARE @FORCE_PAY_DATE VARCHAR(50)
 DECLARE @TLN_REMAINING_AMT VARCHAR(50)
 DECLARE @ARREARS_DAYS VARCHAR(50)
 DECLARE @TLN_TAKEUP_SOURCE VARCHAR(50)
 DECLARE @RESIDUAL_ACC_NR VARCHAR(50)
 DECLARE @RisidualOpenDate Datetime 

  /*Variables to be used in the process below*/
 DECLARE @PROCESS_STATUS varchar(255)
 DECLARE @DAYS_SINCE_TAKE_UP_BUSINESS int
 DECLARE @CURRENT_STATUS_CODE varchar(255)
 DECLARE @DAYS_IN_ARR_BUSINESS int
 DECLARE @DAYS_IN_ARR_CALENDAR int
 DECLARE @DAYS_SINCE_TAKE_UP int
 DECLARE @LAST_PMT_AMT numeric(19,2)
 DECLARE @LAST_PMT_DATE date
 DECLARE @LAST_UPDATE_DATE date
 DECLARE @PROGRESS_FLAG varchar(255)
 DECLARE @RECOVERY_WI_ID bigint
 DECLARE @RES_ACC_OPEN_DATE date
 DECLARE @ORIGINATING_QUEUE varchar(255)
 DECLARE @ACTION_TAKEN varchar(255)
 DECLARE @EVENT_TYPE_ID int =2
 DECLARE @WORK_ITEM_VERSION BIGINT
 DECLARE @USER_ID INT
 DECLARE @StatusID BIGINT
 DECLARE @Note Varchar(100)
 DECLARE @CREATED_DATE DATETIME = GETDATE()
 DECLARE @ALLOCATION_DATE DATETIME = GETDATE()
 DECLARE @ALLOCATION_REASON VARCHAR(20)='1st Allocation'
 DECLARE @ALLOCATION_TYPE VARCHAR(10)='1'
 DECLARE @tblRecoveryID TABLE (ID BIGINT)
 DECLARE @RecoveryID BIGINT
 DECLARE @RecordType varchar(20)
 DECLARE @DAYS_WITH_EDC INT= 0
 DECLARE @END_DATE DATETIME = GETDATE()
 DECLARE @StatusDesc VARCHAR(50) 
 DECLARE @EDC_ID BIGINT
 DECLARE @DETAIL VARCHAR(100)
 DECLARE @tblWorkItem_ID_Date TABLE (ID BIGINT,[DATE] DATETIME )
 DECLARE @WorkItemID BIGINT
 DECLARE @tlbWorkItemHistoryID  TABLE (ID BIGINT)
 DECLARE @WorkItemHistoryID INT
 DECLARE @BusinessAreaID BIGINT 
 DECLARE @CreditMessageID BIGINT 
 DECLARE @tblCreditMessageID TABLE (ID BIGINT)
 DECLARE @CREDIT_WI_ID BIGINT
 DECLARE @tblCaseID TABLE (ID BIGINT)
 DECLARE @CaseID BIGINT
 DECLARE @CaseState BIGINT=1
 DECLARE @CaseType BIGINT=11
 DECLARE @UserID BIGINT
 DECLARE @WORK_ITEM_TYPE_ID BIGINT
 DECLARE @STATUS_ID BIGINT
 DECLARE @QUEUE_ID BIGINT
 DECLARE @WORK_ITEM_STATE_ID BIGINT
 DECLARE @VERSION INT

 /*Initiating a cursor*/
  SET @ExistingLiveAccounts= CURSOR FOR
  SELECT [MPM_TLN_ACCT_NO],[STATUS]
  FROM [App_Recoveries].[Staging].[ImportTLNLive]
  WHERE [MPM_TLN_ACCT_NO] IN
  (SELECT 
      [MPM_ACC_NO]
    
  FROM [App_Recoveries].[dbo].[CREDIT_MESSAGE]
  )

 /*open the  cursor*/
  OPEN  @ExistingLiveAccounts;

 FETCH NEXT FROM @ExistingLiveAccounts INTO @MPM_TLN_ACCT_NO, @STATUS
									

------------------/*Existing Accounts*/---------------------------------------------------------
WHILE @@FETCH_STATUS = 0
BEGIN

  /*Other variables*/
SET @BusinessAreaID =(SELECT [ID] FROM [Plexus].[dbo].[BUSINESS_AREA] WHERE [DESCRIPTION] ='Credit Recoveries Application')
SET @WorkItemID =(SELECT  [WORK_ITEM_ID] FROM [App_Recoveries].[dbo].[CREDIT_MESSAGE] WHERE MPM_ACC_NO =@MPM_TLN_ACCT_NO)
SET @StatusDesc       = CASE WHEN @Status ='GWL' THEN 'ALLOCATED_GWL_MI'
                             WHEN @Status ='FARM' THEN 'ALLOCATED_FARM_MI'
							 WHEN @Status ='DEC' THEN 'DECEASED' 
							 WHEN @Status = 'SEQ' THEN 'SEQUESTRATED'
							 ELSE @Status
							 END
SET @StatusID = (SELECT  [ID]FROM [Plexus].[dbo].[STATUS]WHERE NAME =@StatusDesc AND BUSINESS_AREA_ID=@BusinessAreaID)
SET @EDC_ID = (CASE WHEN @Status ='GWL' THEN 1 WHEN @Status ='FARM' THEN 2 ELSE 0 END)
SET @DETAIL ='Work item''s status has been changed to [' + @StatusDesc + ' ] by initial ETL load'
SET @RECOVERY_WI_ID = (SELECT MAX([RECOVERY_WI_ID])+1 AS [RECOVERY_WI_ID]  FROM [App_Recoveries].[dbo].[RECOVERIES])
SET @WORK_ITEM_VERSION= (SELECT MAX(WORK_ITEM_VERSION)+1 FROM dbo.WORK_ITEM_HISTORY WHERE WORK_ITEM_ID=@WorkItemID)
SET @Note = (SELECT [DESCRIPTION]FROM [Plexus].[dbo].[STATUS]WHERE NAME =@StatusDesc)
SET @USER_ID = (SELECT ID FROM dbo.[USER] WHERE BUSINESS_AREA_ID =@BusinessAreaID AND USER_TYPE_ID=3)
SET @RecoveryID =(SELECT [RECOVERY_ID] FROM [App_Recoveries].[dbo].[CREDIT_MESSAGE] WHERE MPM_ACC_NO =@MPM_TLN_ACCT_NO)



 -----Update WorkItem Status ID---------------------
  UPDATE [Plexus].[dbo].[WORK_ITEM]
  SET [STATUS_ID]=@StatusID
  WHERE ID=@WorkItemID
 -----END of  WorkItem---------------------------

 ----Insert WorkItem History----------
   INSERT INTO WORK_ITEM_HISTORY 
  ([DETAIL],DATE_TIME,[WORK_ITEM_ID],[WORK_ITEM_VERSION],[USER_ID],[EVENT_TYPE_ID]) 
   OUTPUT Inserted.ID INTO  @tlbWorkItemHistoryID(ID)
   VALUES 
  ( @DETAIL,@CREATED_DATE,@WorkItemID,@WORK_ITEM_VERSION,@USER_ID,@EVENT_TYPE_ID)
  
  SET @WorkItemHistoryID =(SELECT ID FROM @tlbWorkItemHistoryID)


  ----END OF WorkItem History------------------

----Insert INTO  WORKITEM HISTORY NOTE------------
  INSERT INTO WORK_ITEM_HISTORY_NOTE
  ([WORK_ITEM_HISTORY_ID],[NOTE])
  VALUES (@WorkItemHistoryID,@Note)
-----END OF WORKITEM HISTORY NOTE----------

-----INSERT ALLOCATION--------------

  IF (SELECT [ID] FROM [App_Recoveries].[dbo].[EDC] WHERE NAME= @Status) IS NOT NULL
  BEGIN
   INSERT INTO [App_Recoveries].[dbo].ALLOCATION
	 ([CREATED_DATE],[ALLOCATION_DATE],[ALLOCATION_REASON],[ALLOCATION_TYPE]  ,[EDC_ID]
	   ,[RECOVERY_ID],[DAYS_WITH_EDC],[END_DATE]
	  )

	VALUES
	(
		@CREATED_DATE,@ALLOCATION_DATE,@ALLOCATION_REASON,@ALLOCATION_TYPE,@EDC_ID
		,@RecoveryID,@DAYS_WITH_EDC,@END_DATE
	)
 END

 DELETE FROM @tlbWorkItemHistoryID
 FETCH NEXT FROM @ExistingLiveAccounts INTO @MPM_TLN_ACCT_NO, @STATUS
 -------END OF INSERT INTO ALLOCATION-------------------------------
END

CLOSE @ExistingLiveAccounts   
DEALLOCATE @ExistingLiveAccounts
--------------End of Existing Accounts-------------------------------------------------------------












/* BEFORE YOU ANALYZE THE CODE READ BELOW

The seciton of code below is for Inserting new  TLN account on plexus,

*/
  /*Declaring a cursor*/

  DECLARE @NewLiveAccounts CURSOR;

   /*Initiating a cursor*/
  SET @NewLiveAccounts= CURSOR FOR
  SELECT [CUST_NO],[PRODUCT],[MPM_TLN_ACCT_NO],[DDA_ACCOUNT_NO],[DDA_SUB_PROD_CDE]
      ,[TLN_TAKE_UP_DATE],[TLN_LOAN_VALUE],[TLN_INIT_FEE],[TLN_TOTAL_AMT],[AMT_REPAID]
      ,[ARREARS],[FORCE_PAY_DATE],[TLN_REMAINING_AMT],[ARREARS_DAYS],[TLN_TAKEUP_SOURCE],[STATUS]
  FROM [App_Recoveries].[Staging].[ImportTLNLive]
  WHERE [MPM_TLN_ACCT_NO] NOT IN
  (SELECT 
      [MPM_ACC_NO]
    
  FROM [App_Recoveries].[dbo].[CREDIT_MESSAGE]
  )

 /*open the  cursor*/
  OPEN  @NewLiveAccounts;

FETCH NEXT FROM @NewLiveAccounts INTO @CUST_NO,@PRODUCT,@MPM_TLN_ACCT_NO,@DDA_ACCOUNT_NO,@DDA_SUB_PROD_CDE,
									 @TLN_TAKE_UP_DATE,@TLN_LOAN_VALUE,@TLN_INIT_FEE,@TLN_TOTAL_AMT,@AMT_REPAID,
									 @ARREARS,@FORCE_PAY_DATE,@TLN_REMAINING_AMT,@ARREARS_DAYS,@TLN_TAKEUP_SOURCE,
									 @STATUS

 ------------------/*New Accounts*/---------------------------------------------------------
WHILE @@FETCH_STATUS = 0
BEGIN

  /*Other variables*/
SET @BusinessAreaID =(SELECT [ID] FROM [Plexus].[dbo].[BUSINESS_AREA] WHERE [DESCRIPTION] ='Credit Recoveries Application')
SET @WorkItemID =(SELECT  [WORK_ITEM_ID] FROM [App_Recoveries].[dbo].[CREDIT_MESSAGE] WHERE MPM_ACC_NO =@MPM_TLN_ACCT_NO)
SET @StatusDesc       = CASE WHEN @Status ='GWL' THEN 'ALLOCATED_GWL_MI'
                             WHEN @Status ='FARM' THEN 'ALLOCATED_FARM_MI'
							 WHEN @Status ='DEC' THEN 'DECEASED' 
							 WHEN @Status = 'SEQ' THEN 'SEQUESTRATED'
							 ELSE @Status
							 END
SET @StatusID = (SELECT  [ID]FROM [Plexus].[dbo].[STATUS]WHERE NAME =@StatusDesc AND BUSINESS_AREA_ID=@BusinessAreaID)
SET @EDC_ID = (CASE WHEN @Status ='GWL' THEN 1 WHEN @Status ='FARM' THEN 2 ELSE 0 END)
SET @DETAIL ='Work item''s status has been changed to [' + @StatusDesc + ' ] by initial ETL load'
SET @RECOVERY_WI_ID = (SELECT MAX([RECOVERY_WI_ID])+1 AS [RECOVERY_WI_ID]  FROM [App_Recoveries].[dbo].[RECOVERIES])
SET @WORK_ITEM_VERSION= 0
SET @Note = (SELECT [DESCRIPTION]FROM [Plexus].[dbo].[STATUS]WHERE NAME =@StatusDesc)
SET @USER_ID = (SELECT ID FROM dbo.[USER] WHERE BUSINESS_AREA_ID =@BusinessAreaID AND USER_TYPE_ID=3)
SET @RecoveryID =(SELECT [RECOVERY_ID] FROM [App_Recoveries].[dbo].[CREDIT_MESSAGE] WHERE MPM_ACC_NO =@MPM_TLN_ACCT_NO)
SET @CREDIT_WI_ID =(SELECT MAX(CREDIT_WI_ID)+1 FROM [App_Recoveries].dbo.CREDIT_MESSAGE)
SET @UserID =(SELECT [ID] FROM [Plexus].[dbo].[USER]WHERE USERNAME LIKE '%crv%' AND BUSINESS_AREA_ID =@BusinessAreaID)
SET @WORK_ITEM_TYPE_ID =( SELECT  ID FROM [Plexus].dbo.WORK_ITEM_TYPE WHERE NAME='EDC_TLN_LIVE')
SET @STATUS_ID = (SELECT[ID] FROM [Plexus].[dbo].[STATUS]  WHERE NAME = 'NEW' AND BUSINESS_AREA_ID =@BusinessAreaID)
SET @QUEUE_ID =(SELECT [ID]   FROM [Plexus].[dbo].[QUEUE]  WHERE NAME='NEW' and BUSINESS_AREA_ID=@BusinessAreaID)
SET @WORK_ITEM_STATE_ID =(SELECT [ID]  FROM [Plexus].[dbo].[WORK_ITEM_STATE]  WHERE STATE = 'UNALLOCATED')
SET @VERSION =1

------INSERT INTO RECOVERIES-------------------------------------------------------------
 INSERT INTO [App_Recoveries].[dbo].[RECOVERIES]
([CREATED_DATE],[PROCESS_STATUS],[DAYS_SINCE_TAKE_UP_BUSINESS],[CURRENT_STATUS_CODE],[DAYS_IN_ARR_BUSINESS],[DAYS_IN_ARR_CALENDAR],[DAYS_SINCE_TAKE_UP]
 ,[LAST_PMT_AMT],[LAST_PMT_DATE],[LAST_UPDATE_DATE],[PROGRESS_FLAG],[RECOVERY_WI_ID],[RESIDUAL_ACC_NR],[RES_ACC_OPEN_DATE],[ORIGINATING_QUEUE]
 ,[ACTION_TAKEN])

OUTPUT Inserted.ID INTO  @tblRecoveryID(ID)
VALUES
(      @CREATED_DATE, @PROCESS_STATUS, @DAYS_SINCE_TAKE_UP_BUSINESS,@CURRENT_STATUS_CODE,@DAYS_IN_ARR_BUSINESS,
      @DAYS_IN_ARR_CALENDAR,@DAYS_SINCE_TAKE_UP,@LAST_PMT_AMT,@LAST_PMT_DATE,@LAST_UPDATE_DATE,@PROGRESS_FLAG,
      @RECOVERY_WI_ID,@RESIDUAL_ACC_NR,@RES_ACC_OPEN_DATE,@ORIGINATING_QUEUE,@ACTION_TAKEN
)
SET @RecoveryID = (SELECT ID FROM @tblRecoveryID)
---------------------End of INSERT INTO RECOVERIES

------------INSERT INTO CREDIT MESSAGE-----------------------------------------------


 INSERT INTO [App_Recoveries].[dbo].[CREDIT_MESSAGE]
(CREATED_DATE,[UCN],[MPM_ACC_NO],[DDA_ACC_NO],[DDA_SUB_PRODUCT],[TAKEUP_DATE],
[TAKEUP_AMOUNT],[TAKEUP_FEE],[TAKEUP_TOTAL],[AMOUNT_REPAID],[ARREARS],[STATUS],
[FORCE_PAY_DATE],[BALANCE],[DAYS_IN_ARREARS],[TAKEUP_CHANNEL],RECOVERY_ID,CREDIT_WI_ID
)
OUTPUT Inserted.ID INTO  @tblCreditMessageID(ID)
VALUES
(GETDATE(),@CUST_NO,@MPM_TLN_ACCT_NO,@DDA_ACCOUNT_NO,@DDA_SUB_PROD_CDE,GETDATE(),
@TLN_LOAN_VALUE,@TLN_INIT_FEE,@TLN_TOTAL_AMT,@AMT_REPAID,@ARREARS,@Status,GETDATE(),
@TLN_REMAINING_AMT,@ARREARS_DAYS,@TLN_TAKEUP_SOURCE,@RecoveryID,@CREDIT_WI_ID
)
SET @CreditMessageID = (SELECT ID FROM @tblCreditMessageID)

--------------------END OF INSERT INTO CREDIT MESSAGE------------------------------------

-------INSERT INTO CASE---------------------------------------------------
 INSERT INTO [dbo].[CASE]
 (
     CASE_STATE_ID, CASE_TYPE_ID, CREATE_DATE,CREATED_BY_USER_ID
 )
 OUTPUT Inserted.ID INTO  @tblCaseID(ID)
 VALUES
 (   @CaseState,@CaseType,@CREATED_DATE ,@UserID      
    
 )
 SET @CaseID = (SELECT ID FROM @tblCaseID)

---Insert Into WorkItem
 INSERT INTO [dbo].[WORK_ITEM]
 (
      [WORK_ITEM_TYPE_ID],[STATUS_ID],[QUEUE_ID],[CREATE_DATE],[CREATED_BY_USER_ID],[LAST_ACTIVITY_DATE]
      ,[LAST_ACTIVITY_BY_USER_ID],[CASE_ID],[WORK_ITEM_STATE_ID],[DESCRIPTION],[VERSION]
 )
 OUTPUT Inserted.ID,Inserted.CREATE_DATE INTO  @tblWorkItem_ID_Date(ID,[Date])

 VALUES
 (   @WORK_ITEM_TYPE_ID,@STATUS_ID,@QUEUE_ID ,@CREATED_DATE , @UserID ,   
    @CREATED_DATE,@UserID,@CaseID,@WORK_ITEM_STATE_ID,@StatusDesc,@VERSION
 )


 SET @WorkItemID =  (SELECT ID FROM @tblWorkItem_ID_Date) 
-------END----------------------------------------


---UPDATE CREDIT MESSAGE----
UPDATE [App_Recoveries].dbo.CREDIT_MESSAGE
SET WORK_ITEM_ID= (SELECT ID FROM @tblWorkItem_ID_Date) 
WHERE ID=@CreditMessageId
----END-----------------


 ----Insert WorkItem History----------
   INSERT INTO WORK_ITEM_HISTORY 
  ([DETAIL],DATE_TIME,[WORK_ITEM_ID],[WORK_ITEM_VERSION],[USER_ID],[EVENT_TYPE_ID]) 
   OUTPUT Inserted.ID INTO  @tlbWorkItemHistoryID(ID)
   VALUES 
  ( @DETAIL,@CREATED_DATE,@WorkItemID,@WORK_ITEM_VERSION,@USER_ID,@EVENT_TYPE_ID)
  
  SET @WorkItemHistoryID =(SELECT ID FROM @tlbWorkItemHistoryID)


  ----END OF WorkItem History------------------

----Insert INTO  WORKITEM HISTORY NOTE------------
  INSERT INTO WORK_ITEM_HISTORY_NOTE
  ([WORK_ITEM_HISTORY_ID],[NOTE])
  VALUES (@WorkItemHistoryID,@Note)
-----END OF WORKITEM HISTORY NOTE----------

-----INSERT ALLOCATION--------------

  IF (SELECT [ID] FROM [App_Recoveries].[dbo].[EDC] WHERE NAME= @Status) IS NOT NULL
  BEGIN
   INSERT INTO [App_Recoveries].[dbo].ALLOCATION
	 ([CREATED_DATE],[ALLOCATION_DATE],[ALLOCATION_REASON],[ALLOCATION_TYPE]  ,[EDC_ID]
	   ,[RECOVERY_ID],[DAYS_WITH_EDC],[END_DATE]
	  )

	VALUES
	(
		@CREATED_DATE,@ALLOCATION_DATE,@ALLOCATION_REASON,@ALLOCATION_TYPE,@EDC_ID
		,@RecoveryID,@DAYS_WITH_EDC,@END_DATE
	)
 END


 DELETE @tblCaseID
 DELETE @tblCreditMessageID
 DELETE @tblRecoveryID
 DELETE @tblWorkItem_ID_Date
 DELETE @tlbWorkItemHistoryID
 
FETCH NEXT FROM @NewLiveAccounts INTO @CUST_NO,@PRODUCT,@MPM_TLN_ACCT_NO,@DDA_ACCOUNT_NO,@DDA_SUB_PROD_CDE,
									 @TLN_TAKE_UP_DATE,@TLN_LOAN_VALUE,@TLN_INIT_FEE,@TLN_TOTAL_AMT,@AMT_REPAID,
									 @ARREARS,@FORCE_PAY_DATE,@TLN_REMAINING_AMT,@ARREARS_DAYS,@TLN_TAKEUP_SOURCE,
									 @STATUS
END

CLOSE @NewLiveAccounts   
DEALLOCATE @NewLiveAccounts
-------------------------------------------------------------------------------------------------







-----------------Risidual Accounts----------------------------------------------------------------------------------

/* BEFORE YOU ANALYZE THE CODE READ BELOW

  

*/
  /*Declaring a cursor*/

  DECLARE @NewResidualAccounts CURSOR;

   /*Initiating a cursor*/
  SET @NewResidualAccounts= CURSOR FOR
  SELECT  [CUST_NO]
		,[PRODUCT]
		,[RESIDUAL_ACC_NR]
		,[DDA_ACCOUNT_NO]
		,[DDA_SUB_PROD_CDE]
		,[STATUS]
  FROM [App_Recoveries].[Staging].[ImportTLNResidual]
  WHERE [RESIDUAL_ACC_NR] NOT IN
  (SELECT 
      [MPM_ACC_NO]
    
  FROM [App_Recoveries].[dbo].[CREDIT_MESSAGE]
  )

 /*open the  cursor*/
  OPEN  @NewResidualAccounts;

FETCH NEXT FROM @NewResidualAccounts INTO @CUST_NO,@PRODUCT,@RESIDUAL_ACC_NR,@DDA_ACCOUNT_NO,@DDA_SUB_PROD_CDE,
									     @STATUS


WHILE @@FETCH_STATUS = 0
BEGIN

  /*Other variables*/
SET @BusinessAreaID =(SELECT [ID] FROM [Plexus].[dbo].[BUSINESS_AREA] WHERE [DESCRIPTION] ='Credit Recoveries Application')
SET @WorkItemID =(SELECT  [WORK_ITEM_ID] FROM [App_Recoveries].[dbo].[CREDIT_MESSAGE] WHERE MPM_ACC_NO =@MPM_TLN_ACCT_NO)
SET @StatusDesc       = CASE WHEN @Status ='GWL' THEN 'ALLOCATED_GWL_MI'
                             WHEN @Status ='FARM' THEN 'ALLOCATED_FARM_MI'
							 WHEN @Status ='DEC' THEN 'DECEASED' 
							 WHEN @Status = 'SEQ' THEN 'SEQUESTRATED'
							 ELSE @Status
							 END
SET @StatusID = (SELECT  [ID]FROM [Plexus].[dbo].[STATUS]WHERE NAME =@StatusDesc AND BUSINESS_AREA_ID=@BusinessAreaID)
SET @EDC_ID = (CASE WHEN @Status ='GWL' THEN 1 WHEN @Status ='FARM' THEN 2 ELSE 0 END)
SET @DETAIL ='Work item''s status has been changed to [' + @StatusDesc + ' ] by initial ETL load'
SET @RECOVERY_WI_ID = (SELECT MAX([RECOVERY_WI_ID])+1 AS [RECOVERY_WI_ID]  FROM [App_Recoveries].[dbo].[RECOVERIES])
SET @WORK_ITEM_VERSION= 0
SET @Note =@StatusDesc
SET @USER_ID = (SELECT ID FROM dbo.[USER] WHERE BUSINESS_AREA_ID =@BusinessAreaID AND USER_TYPE_ID=3)
SET @RecoveryID =(SELECT [RECOVERY_ID] FROM [App_Recoveries].[dbo].[CREDIT_MESSAGE] WHERE MPM_ACC_NO =@MPM_TLN_ACCT_NO)
SET @CREDIT_WI_ID =(SELECT MAX(CREDIT_WI_ID)+1 FROM [App_Recoveries].dbo.CREDIT_MESSAGE)
SET @UserID =(SELECT [ID] FROM [Plexus].[dbo].[USER]WHERE USERNAME LIKE '%crv%' AND BUSINESS_AREA_ID =@BusinessAreaID)
SET @WORK_ITEM_TYPE_ID =( SELECT  ID FROM [Plexus].dbo.WORK_ITEM_TYPE WHERE NAME='EDC_TLN_LIVE')
SET @STATUS_ID = (SELECT[ID] FROM [Plexus].[dbo].[STATUS]  WHERE NAME = 'NEW' AND BUSINESS_AREA_ID =@BusinessAreaID)
SET @QUEUE_ID =(SELECT [ID]   FROM [Plexus].[dbo].[QUEUE]  WHERE NAME='NEW' and BUSINESS_AREA_ID=@BusinessAreaID)
SET @WORK_ITEM_STATE_ID =(SELECT [ID]  FROM [Plexus].[dbo].[WORK_ITEM_STATE]  WHERE STATE = 'UNALLOCATED')
SET @VERSION =1
SET @RisidualOpenDate= GETDATE()

/*INSERT INTO RECOVERIES*/
 INSERT INTO [App_Recoveries].[dbo].[RECOVERIES]
([CREATED_DATE],[PROCESS_STATUS],[DAYS_SINCE_TAKE_UP_BUSINESS],[CURRENT_STATUS_CODE],[DAYS_IN_ARR_BUSINESS],[DAYS_IN_ARR_CALENDAR],[DAYS_SINCE_TAKE_UP]
 ,[LAST_PMT_AMT],[LAST_PMT_DATE],[LAST_UPDATE_DATE],[PROGRESS_FLAG],[RECOVERY_WI_ID],[RESIDUAL_ACC_NR],[RES_ACC_OPEN_DATE],[ORIGINATING_QUEUE]
 ,[ACTION_TAKEN])

OUTPUT Inserted.ID INTO  @tblRecoveryID(ID)
VALUES
(      @CREATED_DATE, @PROCESS_STATUS, @DAYS_SINCE_TAKE_UP_BUSINESS,@CURRENT_STATUS_CODE,@DAYS_IN_ARR_BUSINESS,
      @DAYS_IN_ARR_CALENDAR,@DAYS_SINCE_TAKE_UP,@LAST_PMT_AMT,@LAST_PMT_DATE,@LAST_UPDATE_DATE,@PROGRESS_FLAG,
      @RECOVERY_WI_ID,@RESIDUAL_ACC_NR,@RES_ACC_OPEN_DATE,@ORIGINATING_QUEUE,@ACTION_TAKEN
)
SET @RecoveryID = (SELECT ID FROM @tblRecoveryID)
---------------------End of INSERT INTO RECOVERIES

------------INSERT INTO CREDIT MESSAGE-----------------------------------------------


 INSERT INTO [App_Recoveries].[dbo].[CREDIT_MESSAGE]
(CREATED_DATE,[UCN],[MPM_ACC_NO],[DDA_ACC_NO],[DDA_SUB_PRODUCT],[TAKEUP_DATE],
[STATUS],RECOVERY_ID,CREDIT_WI_ID
)
OUTPUT Inserted.ID INTO  @tblCreditMessageID(ID)
VALUES
(GETDATE(),@CUST_NO,@RESIDUAL_ACC_NR,@DDA_ACCOUNT_NO,@DDA_SUB_PROD_CDE,GETDATE(),
@Status,@RecoveryID,@CREDIT_WI_ID
)
SET @CreditMessageID = (SELECT ID FROM @tblCreditMessageID)

--------------------END OF INSERT INTO CREDIT MESSAGE------------------------------------

-------INSERT INTO CASE---------------------------------------------------
 INSERT INTO [dbo].[CASE]
 (
     CASE_STATE_ID, CASE_TYPE_ID, CREATE_DATE,CREATED_BY_USER_ID
 )
 OUTPUT Inserted.ID INTO  @tblCaseID(ID)
 VALUES
 (   @CaseState,@CaseType,@CREATED_DATE ,@UserID      
    
 )
 SET @CaseID = (SELECT ID FROM @tblCaseID)

---Insert Into WorkItem
 INSERT INTO [dbo].[WORK_ITEM]
 (
      [WORK_ITEM_TYPE_ID],[STATUS_ID],[QUEUE_ID],[CREATE_DATE],[CREATED_BY_USER_ID],[LAST_ACTIVITY_DATE]
      ,[LAST_ACTIVITY_BY_USER_ID],[CASE_ID],[WORK_ITEM_STATE_ID],[DESCRIPTION],[VERSION]
 )
 OUTPUT Inserted.ID,Inserted.CREATE_DATE INTO  @tblWorkItem_ID_Date(ID,[Date])

 VALUES
 (   @WORK_ITEM_TYPE_ID,@STATUS_ID,@QUEUE_ID ,@CREATED_DATE , @UserID ,   
    @CREATED_DATE,@UserID,@CaseID,@WORK_ITEM_STATE_ID,@StatusDesc,@VERSION
 )


 SET @WorkItemID =  (SELECT ID FROM @tblWorkItem_ID_Date) 
-------END----------------------------------------


---UPDATE CREDIT MESSAGE----
UPDATE [App_Recoveries].dbo.CREDIT_MESSAGE
SET WORK_ITEM_ID= (SELECT ID FROM @tblWorkItem_ID_Date) 
WHERE ID=@CreditMessageId
----END-----------------


 ----Insert WorkItem History----------
   INSERT INTO WORK_ITEM_HISTORY 
  ([DETAIL],DATE_TIME,[WORK_ITEM_ID],[WORK_ITEM_VERSION],[USER_ID],[EVENT_TYPE_ID]) 
   OUTPUT Inserted.ID INTO  @tlbWorkItemHistoryID(ID)
   VALUES 
  ( @DETAIL,@CREATED_DATE,@WorkItemID,@WORK_ITEM_VERSION,@USER_ID,@EVENT_TYPE_ID)
  
  SET @WorkItemHistoryID =(SELECT ID FROM @tlbWorkItemHistoryID)


  ----END OF WorkItem History------------------

----Insert INTO  WORKITEM HISTORY NOTE------------
  INSERT INTO WORK_ITEM_HISTORY_NOTE
  ([WORK_ITEM_HISTORY_ID],[NOTE])
  VALUES (@WorkItemHistoryID,@Note)
-----END OF WORKITEM HISTORY NOTE----------

-----INSERT ALLOCATION--------------

  IF (SELECT [ID] FROM [App_Recoveries].[dbo].[EDC] WHERE NAME= @Status) IS NOT NULL
  BEGIN
   INSERT INTO [App_Recoveries].[dbo].ALLOCATION
	 ([CREATED_DATE],[ALLOCATION_DATE],[ALLOCATION_REASON],[ALLOCATION_TYPE]  ,[EDC_ID]
	   ,[RECOVERY_ID],[DAYS_WITH_EDC],[END_DATE]
	  )

	VALUES
	(
		@CREATED_DATE,@ALLOCATION_DATE,@ALLOCATION_REASON,@ALLOCATION_TYPE,@EDC_ID
		,@RecoveryID,@DAYS_WITH_EDC,@END_DATE
	)
 END


 DELETE @tblCaseID
 DELETE @tblCreditMessageID
 DELETE @tblRecoveryID
 DELETE @tblWorkItem_ID_Date
 DELETE @tlbWorkItemHistoryID
 
FETCH NEXT FROM @NewResidualAccounts INTO @CUST_NO,@PRODUCT,@RESIDUAL_ACC_NR,@DDA_ACCOUNT_NO,@DDA_SUB_PROD_CDE,
									 @STATUS

END

CLOSE @NewResidualAccounts   
DEALLOCATE @NewResidualAccounts
-------------------------------------------------------------------------------------------------