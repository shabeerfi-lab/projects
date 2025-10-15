USE [App_Recoveries]
GO
/****** Object:  StoredProcedure [dbo].[Closure_Residual_Balance]    Script Date: 08/15/2018 08:08:39 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Closure_Residual_Balance]
AS

DECLARE @COMMITTRAN BIT; 
SET @COMMITTRAN = 1

BEGIN TRANSACTION 

DECLARE @ExistingLiveAccounts CURSOR;
 
 DECLARE @REC_ID int
 DECLARE @RECOVERY_WI_ID int
 DECLARE @Current_Queue varchar(100)
 DECLARE @PROCESS_STATUS varchar(100)
 DECLARE @STATUS varchar(100)
 DECLARE @BALRECID varchar(100)
 DECLARE @tlbWorkItemHistoryID  TABLE (ID BIGINT)
 DECLARE @WorkItemHistoryID INT
 Declare @end_date as datetime

 

set @end_date = getdate();

SET @ExistingLiveAccounts= CURSOR FOR
WITH CTEBal AS
(
  Select *
from (
SELECT [ID]
      ,[CREATED_DATE]
      ,[PRODUCT_BALANCE]
      ,[DATE_UPDATED]
      ,[REDISUAL_BALANCE]
      ,[RESIDUAL_UPDATE_DATE]
      ,[RECOVERY_ID]
      ,row_number() over (partition by [RECOVERY_ID] order by [DATE_UPDATED]desc) r
  FROM [App_Recoveries].[dbo].[BALANCE]
  --where RECOVERY_ID = 1
  )main
  
  where r  = 1
  and [REDISUAL_BALANCE] = 0 
)


SELECT  rec.id,Rec.[RECOVERY_WI_ID],Q.Name 
		,Rec.PROCESS_STATUS,CRM.STATUS,bal.RECOVERY_ID
		
--into #Temp

  FROM CTEBal BAL
  join [App_Recoveries].dbo.RECOVERIES Rec
  on BAL.[RECOVERY_ID] = Rec.ID
  
  join [App_Recoveries].dbo.CREDIT_MESSAGE CRM
  on Rec.ID = CRM.[RECOVERY_ID]
  
  join [Plexus_Recoveries].[dbo].[WORK_ITEM] WI
  on Rec.[RECOVERY_WI_ID] = WI.ID
  
  join [Plexus_Recoveries].[dbo].[QUEUE] Q
  on WI.[QUEUE_ID] = Q.ID
  
  where CRM.status in ('NEW','OPEN')
  
 and (Rec.[PROCESS_STATUS]in ('ALLOCATED','DIALLER','BELOW_CLOSURE_BALANCE')
  or (Rec.[PROCESS_STATUS] is null))
  
  
  and rec.RESIDUAL_ACC_NR is not null 
  
  OPEN  @ExistingLiveAccounts;

 FETCH NEXT FROM @ExistingLiveAccounts INTO  @REC_ID,@RECOVERY_WI_ID,@Current_Queue,@PROCESS_STATUS,@STATUS,@BALRECID
  WHILE @@FETCH_STATUS = 0
BEGIN


-----------------------------------------------------------------------------------------------------------  
  Update [Plexus_Recoveries].[dbo].[WORK_ITEM]
  set [QUEUE_ID] = (SELECT [ID]      
					 FROM [Plexus_Recoveries].[dbo].[QUEUE]
					  where Name = 'CLOSED'),
	[Status_id]	=	 (SELECT [ID]      
					 FROM [Plexus_Recoveries].[dbo].[STATUS]
					  where Name = 'ACC_BALANCE_ZERO') 
	Where ID =	@RECOVERY_WI_ID	  
-----------------------------------------------------------------------------------------------------------
  Insert [Plexus_Recoveries].[dbo].[WORK_ITEM_HISTORY]
  ([DETAIL]
      ,[DATE_TIME]
      ,[WORK_ITEM_ID]
      ,[WORK_ITEM_VERSION]
      ,[USER_ID]
      ,[EVENT_TYPE_ID])
       OUTPUT Inserted.ID INTO  @tlbWorkItemHistoryID(ID)
  Values ('Work item status has been changed to [ACC_BALANCE_ZERO] in queue [Closed ].',
	  @end_date,
	  @RECOVERY_WI_ID,
      1,
	  (SELECT  [ID]      
					 FROM [Plexus_Recoveries].[dbo].[USER]
						where USERNAME = '*CRV'),
	  (SELECT[ID]
                          FROM [Plexus_Recoveries].[dbo].[EVENT_TYPE]
                           where TYPE = 'WORK_ITEM_STATUS_CHANGED'))
              
SET @WorkItemHistoryID =(SELECT max(ID) FROM @tlbWorkItemHistoryID)
-----------------------------------------------------------------------------------------------------------
  Insert into [Plexus_Recoveries].[dbo].[WORK_ITEM_HISTORY_NOTE]([WORK_ITEM_HISTORY_ID],[NOTE])
  VALUES (@WorkItemHistoryID,'Account settled ' + @Current_Queue )
-----------------------------------------------------------------------------------------------------------  
  Update [App_Recoveries].[dbo].[ALLOCATION]
  set [END_DATE] = @end_date
  where [RECOVERY_ID] = @REC_ID
  and [END_DATE] is null
-----------------------------------------------------------------------------------------------------------  
  Update [App_Recoveries].[dbo].[CREDIT_MESSAGE]
  set [STATUS] = 'CLOSED'
  Where [RECOVERY_ID] = @REC_ID
 ---------------------------------------------------------------------------------------------------------
  Update [App_Recoveries].[dbo].[RECOVERIES]
  set [PROCESS_STATUS] = 'CLOSED'
  Where [ID] = @REC_ID
 ---------------------------------------------------------------------------------------------------------
 
 FETCH NEXT FROM @ExistingLiveAccounts INTO  @REC_ID,@RECOVERY_WI_ID,@Current_Queue,@PROCESS_STATUS,@STATUS,@BALRECID
END

CLOSE @ExistingLiveAccounts   
DEALLOCATE @ExistingLiveAccounts
  
IF @COMMITTRAN = 1  
BEGIN 
    COMMIT TRANSACTION 
    PRINT N'SCRIPT COMPLETED AND COMMITTED SUCCESSFULLY' 
END 
ELSE BEGIN 
    ROLLBACK TRANSACTION 
    PRINT N'SCRIPT COMPLETED AND ROLLED BACK SUCCESSFULLY' 
END
