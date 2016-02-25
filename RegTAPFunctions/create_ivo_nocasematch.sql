DROP FUNCTION [dbo].[ivo_nocasematch]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[ivo_nocasematch] (@value varchar(max), @pat varchar(max))

--select dbo.ivo_nocasematch ('abcdef','%bcd%')
--select dbo.ivo_nocasematch ('abcdef','%fgh%')

RETURNS int
AS
BEGIN
	declare @returnValue int

	set @returnValue=
	case
		when  @value like @pat then 1
		else 0
	end

return @returnValue
END

GO





