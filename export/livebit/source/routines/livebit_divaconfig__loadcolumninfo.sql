CREATE   PROCEDURE [divaconfig].[LoadColumnInfo]
    @SchemaName SYSNAME,
    @TableName SYSNAME
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [divaconfig].[ColumnInfo] (
        DatabaseName,
        SchemaName,
        TableName,
        ColumnName,
        ColumnSort,
        DataType,
        MaxLengthOrValue,
        IsNullable,
        IsPrimaryKey,
        IsForeignKey,
        IsIdentity,
        IsInt,
        IsFloat,
        IsDate,
        IsTime,
        IsDateTime,
        CreatedAt,
        UpdatedAt
    )
    SELECT  
        DB_NAME() AS DatabaseName,
        c.TABLE_SCHEMA,
        c.TABLE_NAME,
        c.COLUMN_NAME,
        c.ORDINAL_POSITION AS ColumnSort,
        c.DATA_TYPE,
        CASE 
            WHEN c.CHARACTER_MAXIMUM_LENGTH IS NOT NULL 
                 THEN CAST(c.CHARACTER_MAXIMUM_LENGTH AS NVARCHAR(255))
        END AS MaxLengthOrValue,
        CASE WHEN c.IS_NULLABLE = 'YES' THEN 1 ELSE 0 END AS IsNullable,
        CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 1 ELSE 0 END AS IsPrimaryKey,
        CASE WHEN fk.COLUMN_NAME IS NOT NULL THEN 1 ELSE 0 END AS IsForeignKey,
        COLUMNPROPERTY(OBJECT_ID(c.TABLE_SCHEMA + '.' + c.TABLE_NAME), c.COLUMN_NAME, 'IsIdentity') AS IsIdentity,
        CASE WHEN c.DATA_TYPE IN ('int','bigint','smallint','tinyint') THEN 1 ELSE 0 END AS IsInt,
        CASE WHEN c.DATA_TYPE IN ('float','real','decimal','numeric') THEN 1 ELSE 0 END AS IsFloat,
        CASE WHEN c.DATA_TYPE IN ('date') THEN 1 ELSE 0 END AS IsDate,
        CASE WHEN c.DATA_TYPE IN ('time') THEN 1 ELSE 0 END AS IsTime,
        CASE WHEN c.DATA_TYPE IN ('datetime','datetime2','smalldatetime') THEN 1 ELSE 0 END AS IsDateTime,
        GETDATE() AS CreatedAt,
        GETDATE() AS UpdatedAt
    FROM INFORMATION_SCHEMA.COLUMNS c
    LEFT JOIN (
        SELECT ku.TABLE_SCHEMA, ku.TABLE_NAME, ku.COLUMN_NAME
        FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
        INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE ku
            ON tc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
        WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
    ) pk ON c.TABLE_SCHEMA = pk.TABLE_SCHEMA AND c.TABLE_NAME = pk.TABLE_NAME AND c.COLUMN_NAME = pk.COLUMN_NAME
    LEFT JOIN (
        SELECT kcu.TABLE_SCHEMA, kcu.TABLE_NAME, kcu.COLUMN_NAME
        FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS rc
        INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
            ON rc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    ) fk ON c.TABLE_SCHEMA = fk.TABLE_SCHEMA AND c.TABLE_NAME = fk.TABLE_NAME AND c.COLUMN_NAME = fk.COLUMN_NAME
    WHERE c.TABLE_SCHEMA = @SchemaName
      AND c.TABLE_NAME = @TableName;
END;
