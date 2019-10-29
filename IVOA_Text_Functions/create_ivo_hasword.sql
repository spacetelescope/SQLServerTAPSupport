DROP FUNCTION [dbo].[ivo_hasword]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[ivo_hasword] (@haystack varchar(max), @needle varchar(max))

--select dbo.ivo_hasword ('abcdef','bcd') -- word not found at all

-- last word
--select dbo.ivo_hasword ('abc def ghi','ghi') -- yes, space
--select dbo.ivo_hasword ('abc def#ghi','ghi') -- yes, non-letter
--select dbo.ivo_hasword ('abc defKghi','ghi') -- no, proves case insensitive
--select dbo.ivo_hasword ('abc def0ghi','ghi') -- yes, non-letter, or is a number considered a letter
--select dbo.ivo_hasword ('abc def	ghi','ghi') -- yes, tab character
--select dbo.ivo_hasword ('abc def' + char(13) + 'ghi','ghi') -- yes, CR embedded in string

-- first word
--select dbo.ivo_hasword ('abc def ghi','abc') -- yes

-- word in string
--select dbo.ivo_hasword ('abc def ghi','def') -- yes
--select dbo.ivo_hasword ('abc def ghi','def ') -- yes, in this 'def ' has a space so it finds it, is this OK?
--select dbo.ivo_hasword ('abc def#ghi','def') -- yes
--select dbo.ivo_hasword ('abc deffghi','def') -- no
--select dbo.ivo_hasword ('abc%def ghi','def') -- yes
--select dbo.ivo_hasword ('abcDdef ghi','def') -- no
--select dbo.ivo_hasword ('abcdef','fgh') -- no, word embedded inside another word

RETURNS int
AS
BEGIN
	declare @returnValue int
	declare @index int
	

	set @index=charindex(@needle, @haystack)
	-- if the word wasn't found at all
	if @index=0
	begin
		return @index
	end

	-- if the first word
	if ((@index=1) and (substring(@haystack, len(@needle)+1, 1) not like '[abcdefghijklmnopqrstuvwxyz]'))
	begin
		return 1
	end
	-- if the last word
	if ((@index+len(@needle)-1)=len(@haystack) and (substring(@haystack, @index-1, 1) not like '[abcdefghijklmnopqrstuvwxyz]'))
	begin
		return 1
	end

	-- if a word in the string but not the first or last word
	-- test if the  character after the word is not a letter
	-- and test if the character before the word is not a letter
	-- then return 1 if true
	if ((substring(@haystack, @index+len(@needle), 1) not like '[abcdefghijklmnopqrstuvwxyz]') -- character after word
		and (substring(@haystack, @index-1, 1) not like '[abcdefghijklmnopqrstuvwxyz]')) -- character before word
	begin
		return 1
	end

	return 0
END

GO





