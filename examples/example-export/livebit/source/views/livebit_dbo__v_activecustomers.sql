CREATE VIEW [dbo].[v_ActiveCustomers] AS
SELECT c.[Id], c.[Name], d.[FullDate] AS [SignupDate]
FROM [dbo].[Customers] c
LEFT JOIN [divadim].[DimDate] d ON d.[DateKey] = c.[SignupDateKey]
WHERE ISNULL(c.[Name], '') <> ''
