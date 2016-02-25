DROP FUNCTION [dbo].[ivo_hashlist_has]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[ivo_hashlist_has] (@hashlist varchar(max), @item varchar(max))

--select dbo.ivo_hashlist_has ('#abcdef#ghi#jkl#mno#pqr#stu#','bcd') -- not found
--select dbo.ivo_hashlist_has ('#abcdef#ghi#jkl#mno#pqr#stu#','stu') -- found
--select dbo.ivo_hashlist_has ('#abcdef#ghi#jkl#mno#pqr#stu#','xyz') -- not found

RETURNS int
AS
BEGIN
	declare @returnValue int

	set @returnValue=
	case
		when exists (select * from dbo.split(@hashList, '#') where data=@item) then 1
		else 0
	end

return @returnValue
END

GO





