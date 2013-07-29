USE [ILM_PROFILE]

GO

/****** Object:  StoredProcedure [dbo].[Get_SSIS_DailyUsageEmail_CurrentValues]    Script Date: 07/27/2013 16:50:28 ******/
IF EXISTS (SELECT *
           FROM   sys.objects
           WHERE  object_id = OBJECT_ID(N'[dbo].[Get_SSIS_DailyUsageEmail_CurrentValues]')
                  AND TYPE IN ( N'P', N'PC' ))
  DROP PROCEDURE [dbo].[Get_SSIS_DailyUsageEmail_CurrentValues]

GO

USE [ILM_PROFILE]

GO

/****** Object:  StoredProcedure [dbo].[Get_SSIS_DailyUsageEmail_CurrentValues]    Script Date: 07/27/2013 16:50:28 ******/
SET ANSI_NULLS ON

GO

SET QUOTED_IDENTIFIER ON

GO

/*
 * PROCEDURE	: Get_SSIS_DailyUsageEmail_CurrentValues
 *
 * DEFINITION	: Called from the SSIS_DailyEmail ssis package to get the current settings of the email
 *             
 * CREATOR		:Psingla
 * RETURN CODE	: 
 */
CREATE PROC [dbo].[Get_SSIS_DailyUsageEmail_CurrentValues]
AS
  BEGIN
      SET NOCOUNT ON

      /************************************************/
      BEGIN TRY
          DECLARE @ErrorMessage    NVARCHAR(1000),
                  @ErrorMessageext NVARCHAR(1000),
                  @ErrorSeverity   INT,
                  @ErrorState      INT,
                  @ErrorNumber     INT;

          DECLARE @tv_Count AS TABLE (
            TargetID    VARCHAR(50) NULL,
            recordcount INT )

          --Declare variables
          DECLARE @sEmailSendTo   VARCHAR(8000),
                  @sEmailSendFrom VARCHAR(8000)

          DECLARE @sEmailSubject   NVARCHAR(255),
                  @sEmailBody      NVARCHAR(4000),
                  @i32ProfileCount INT,
                  @i32DomainCount  INT,
                  @sYesterdayDate  CHAR(12)

          DECLARE @TodayMidNight DATETIME

          SET @TodayMidNight=cast(convert(VARCHAR(10), getdate(), 101) AS DATETIME)

          ----1
          SELECT @sEmailSendTo = ParameterValue
          FROM   dbo.ConfigurationParameter
          WHERE  ParameterName = 'ILMAdministratorEmailAddress'

          IF @sEmailSendTo IS NULL
            RAISERROR('No Valid send to Email address exists in ConfigurationParameter table. The value ConfigurationParameter.ParameterValue         
          WHERE  ParameterName = ILMAdministratorEmailAddress is null',
                      16,
                      1)

          ----2
          SELECT @sEmailSendFrom = ParameterValue
          FROM   dbo.ConfigurationParameter
          WHERE  ParameterName = 'NoReplyFromEmailAddress'

          IF @sEmailSendTo IS NULL
            RAISERROR('No Valid send from Email address exists in ConfigurationParameter table.The value  ConfigurationParameter.ParameterValue         
          WHERE  ParameterName = NoReplyFromEmailAddress is null',
                      16,
                      1)

          ---3
          SELECT @sEmailSubject = et.subject,
                 @sEmailBody = et.body
          FROM   dbo.EmailTemplate et
          WHERE  et.EmailDescription = 'AMSUsageReport'

          IF @sEmailSubject IS NULL
              OR @sEmailBody IS NULL
            RAISERROR('No Valid subject or body exists exists in ConfigurationParameter table.The value EmailTemplate.subject  or  EmailTemplate.body       
          WHERE  EmailDescription = AMSUsageReport is null',
                      16,
                      1)

          INSERT INTO @tv_Count
          SELECT TargetID,
                 count (1)
          FROM   dbo.ActionHistory_PasswordProfile
          WHERE  ActionDTM >= dateadd(dd, -1, @TodayMidNight)
                 AND ActionDTM < @TodayMidNight
                 AND TargetID IN ( 'DOMAIN.COM', 'PROFILE' )
          GROUP  BY TargetID

          --4
          SELECT @i32ProfileCount = recordcount
          FROM   @tv_Count
          WHERE  TargetID = 'PROFILE'

          SELECT @i32DomainCount = recordcount
          FROM   @tv_Count
          WHERE  TargetID = 'DOMAIN.COM'

          SET @sYesterdayDate=CONVERT(CHAR(12), dateadd(dd, -1, @TodayMidNight), 0)
          set @sEmailBody=replace(@sEmailBody, '%Yesterday’s Date; [Month Day, Year format]%', @sYesterdayDate+'<br>')
          set @sEmailBody=replace(@sEmailBody, '%Count of records in ILM_PROFILE\ActionHistory_PasswordProfile where TargetID = PROFILE and ActionDTM is yesterday’s date%', cast(@i32ProfileCount as nvarchar(12))+'<br>')
          set @sEmailBody=replace(@sEmailBody, '%Count of records in ILM_PROFILE\ActionHistory_PasswordProfile where TargetID = DOMAIN.COM and ActionDTM is yesterday’s date%', cast(@i32DomainCount as nvarchar(12)))

          ---Send result set to the calling enviornment
          SELECT @sEmailSendTo                                                                         AS sEmailSendTo,
                 @sEmailSendFrom                                                                       AS sEmailSendFrom,
                 @sEmailSubject                                                                        AS sEmailSubject,
                 @sEmailBody AS sEmailBody,
                 @i32ProfileCount                                                                      AS i32ProfileCount,
                 @i32DomainCount                                                                       AS i32DomainCount,
                 @sYesterdayDate                                                                       AS sYesterdayDate
      END TRY

      /************************************************/
      BEGIN CATCH
          SELECT @ErrorNumber = ERROR_NUMBER(),
                 @ErrorMessage = ERROR_MESSAGE(),
                 @ErrorMessageext = CASE
                                      WHEN ERROR_PROCEDURE() IS NULL THEN 'SQLError#: ' + convert(VARCHAR, @ErrorNumber) + ', "' + ERROR_MESSAGE() + '"' + ', Sql in Procedure: ' + isnull(OBJECT_NAME(@@PROCID), '') + ', Line#: ' + convert(VARCHAR, ERROR_LINE())
                                      ELSE 'SQLError#: ' + convert(VARCHAR, @ErrorNumber) + ', "' + ERROR_MESSAGE() + '"' + ', Procedure: ' + isnull(ERROR_PROCEDURE(), '') + ', Line#: ' + convert(VARCHAR, ERROR_LINE())
                                    END,
                 @ErrorSeverity = ERROR_SEVERITY(),
                 @ErrorState = ERROR_STATE();

          RAISERROR (@ErrorMessageext,
                     @ErrorSeverity,
                     @ErrorState);
      END CATCH
  /************************************************/
  END

GO 
