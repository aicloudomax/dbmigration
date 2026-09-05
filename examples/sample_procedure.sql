-- Example T-SQL procedure for trying out `dbmigrate convert`.
--   dbmigrate convert examples/sample_procedure.sql --schema sales_dbo
CREATE PROCEDURE dbo.usp_UpsertCustomer
    @Id        int,
    @Name      nvarchar(100),
    @Email     nvarchar(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Id IS NULL
        SET @Id = SCOPE_IDENTITY();

    SELECT TOP 5 *
    FROM Customers
    WHERE Name = @Name;

    UPDATE Customers
       SET Email     = ISNULL(@Email, Email),
           UpdatedAt = GETDATE()
     WHERE Id = @Id;
END
