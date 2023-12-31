USE [APPLICATIONS]
GO
/****** Object:  StoredProcedure [dbo].[SP_InsertDataIntoUNEPARTIEDEJOINDRE]    Script Date: 18/04/2023 12:12:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[SP_InsertDataIntoUNEPARTIEDEJOINDRE]
AS
BEGIN
    BEGIN TRY
        DECLARE @CurrentMonth INT;
        DECLARE @CurrentYear INT;
        DECLARE @IDPOLE INT;
        DECLARE @CodeFamille VARCHAR(5);
        DECLARE @NomPole VARCHAR(100);
        DECLARE @SQL NVARCHAR(MAX);
        SET @CurrentMonth = MONTH(GETDATE()) - 1;
        SET @CurrentYear = CASE
            WHEN @CurrentMonth = 0 THEN YEAR(GETDATE()) - 1
            ELSE YEAR(GETDATE())
        END;

        DECLARE db_cursor CURSOR FOR
        SELECT IDPOLE, CodeFamille, NomPole
        FROM POLEMONITORING;

        OPEN db_cursor;
        FETCH NEXT FROM db_cursor INTO @IDPOLE, @CodeFamille, @NomPole;

        WHILE @@FETCH_STATUS <>-1
        BEGIN
		-- Vérifier si la table JOINDRE_ du pôle existe
			IF EXISTS (SELECT * FROM sys.tables WHERE name = 'JOINDRE_' + CAST(@IDPOLE AS NVARCHAR(10)))
				BEGIN
				SET @SQL = N'
					INSERT INTO  Monitoring.dbo.UNEPARTIEDEJOINDRE (NumeroDossierTps, CodeFormulaire, NiveauExecution, DateRequete, DateRetour, NomPole, Periode, Annee, CodeFamille, Signataire, ImportationOuExportation)
					SELECT DISTINCT do.NUMERODOSSIERTPS,jo.CODEFORMULAIRE, 
					CASE
						WHEN niveauexecution = ''EnCoursDouane'' THEN ''dlv''
						WHEN niveauexecution = ''Amodifier'' THEN ''mod''
						WHEN niveauexecution = ''Aannuler'' THEN ''ann''
						WHEN niveauexecution = ''Rejet'' THEN ''rej''
						WHEN niveauexecution = ''Initialise'' THEN ''enc''
						ELSE niveauexecution 
					END AS niveauexecution,
					daterequete, dateretour, @NomPole, @CurrentMonth, @CurrentYear, @CodeFamille, ''SIGNATAIRE'', do.IMPORTATIONOUEXPORtATION
					FROM DOSSIERTPS DO
					INNER JOIN JOINDRE_' + CAST(@IDPOLE AS NVARCHAR(10)) + ' JO ON DO.NUMERODOSSIERTPS = JO.NUMERODOSSIERTPS
					INNER JOIN operateur OP ON OP.idtpsoperateur = DO.idtpsoperateur
					WHERE MONTH(daterequete) = @CurrentMonth
					AND YEAR(daterequete) = @CurrentYear
					AND codeformulaire <> ''001''
					AND codeformulaire <> ''1004''
					ORDER BY 1;';

				EXEC sp_executesql @SQL, N'@IDPOLE INT, @CodeFamille VARCHAR(5), @NomPole VARCHAR(100), @CurrentMonth INT, @CurrentYear INT', @IDPOLE, @CodeFamille, @NomPole, @CurrentMonth, @CurrentYear;
				END
			 ELSE
				BEGIN
					-- Enregistrer l'erreur dans la table ErrorLog
					INSERT INTO Monitoring.dbo.ErrorLog (ErrorMessage, ErrorSeverity, ErrorState)
					VALUES ('La table JOINDRE_' + CAST(@IDPOLE AS NVARCHAR(10)) + ' du pôle correspondant n''existe pas', 16, 1);
				END
            FETCH NEXT FROM db_cursor INTO @IDPOLE, @CodeFamille, @NomPole;			            
        END;

        CLOSE db_cursor;
        DEALLOCATE db_cursor;
    END TRY
    BEGIN CATCH
        -- En cas d'erreur, insérer les détails de l'erreur dans la table ErrorLog
        DECLARE @ErrorMessage NVARCHAR(4000);
        DECLARE @ErrorSeverity INT;
        DECLARE @ErrorState INT;

        SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();

        INSERT INTO Monitoring.dbo.ErrorLog (ErrorMessage, ErrorSeverity, ErrorState)
        VALUES (@ErrorMessage, @ErrorSeverity, @ErrorState);

		-- Fermer le curseur et désallouer les ressources
        --CLOSE db_cursor;
        --DEALLOCATE db_cursor;
		IF CURSOR_STATUS('global', 'db_cursor') >= 0
		BEGIN
			CLOSE db_cursor;
			DEALLOCATE db_cursor;
		END;

        -- Lancer une nouvelle erreur pour être capturée par l'application
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
