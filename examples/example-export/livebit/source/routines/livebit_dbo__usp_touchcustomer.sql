CREATE PROCEDURE [dbo].[usp_TouchCustomer] @CustomerId int AS
UPDATE dbo.Customers SET Name = Name WHERE Id = @CustomerId;
