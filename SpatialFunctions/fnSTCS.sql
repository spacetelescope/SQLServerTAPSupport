select 'Installing STC functions'
/*******************************************************************************************************************************/
---------------------------------------------------------------------------------------------------------------------
BEGIN TRY DROP FUNCTION [fnStc_ParseRegionDefinition] END TRY BEGIN CATCH END CATCH
go
CREATE FUNCTION [dbo].[fnStc_ParseRegionDefinition](@regionDefinition varchar(max))
RETURNS @vertexList TABLE(regionNumber int, regionSys char(3), regionType varchar(32), coordSys varchar(48), 
                          pointNumber int, xVal1 varchar(max), yVal1 varchar(max), xVal2 varchar(max), yVal2 varchar(max))
-- Function to convert region definitions into a list of region vertices
-- Note that JHU syntax is same as STC except it allows multiple regions. JHU has J2000 defined but STC does not.
AS BEGIN
	-- declare variables
	declare @regionNumber int=0, @regionSys char(3)=null, @regionType varchar(32)=null, @regionData varchar(max)=null
	declare @pointNumber int=0, @xVal1 varchar(max)=null, @yVal1 varchar(max)=null, @xVal2 varchar(max)=null, @yVal2 varchar(max)=null
	DECLARE @geographyType varchar(32)
	DECLARE @geographyData varchar(max)
	DECLARE @geographyCount int=0, @length int=0, @dataLength int=0
	DECLARE @idx int=-1, @idx1 int=-1, @idx2 int=-1, @idx3 int=-1, @idx4 int=-1, @idx5 int=-1, @idx6 int=-1, @idx7 int=-1, @idx8 int=-1
	declare @idxPoint int=-1, @idxMultiPoint int=-1, @idxLinestring int=-1, @idxMultiLinestring int=-1
	declare @idxPolygon int=-1, @idxMultiPolygon int=-1, @idxGeometryCollection int=-1
	declare @idxPosition int=-1, @idxCircle int=-1, @idxBox int=-1, @idxRange int=-1
	declare @idxEcliptic int=-1, @idxFk4 int=-1, @idxFk5 int=-1, @idxGalactic int=-1, @idxJ2000 int=-1
	declare @idxIcrs int=-1, @idxUnknownFrame int=-1, @idxMjd int=-1, @idxGsc1 int=-1, @idxWavelength int=-1, @idxOther int=-1
	declare @idxBarycenter int=-1, @idxGeocenter int=-1, @idxHeliocenter int=-1, @idxTopocenter int=-1
	declare @idxRelocatable int=-1, @idxUnknownRefpos int=-1, @idxLsr int=-1
	declare @idxCartesian1 int=-1, @idxCartesian2 int=-1, @idxCartesian3 int=-1, @idxSpherical2 int=-1
	declare @idxParentheses int=-1, @idxComma int=-1, @idxSpace int=-1
	declare @idxUnion int=-1, @idxIntersection int=-1, @idxNot int=-1
	declare @idxRegionStart int=-1, @idxRegionEnd int=-1
	DECLARE @frameType varchar(16)='', @refposType varchar(16)='', @flavorType varchar(16)='', @coordSys varchar(48)=''
	declare @dataValues TABLE(dataValues varchar(max))
	declare @nValues int, @xVal varchar(max), @yVal varchar(max)
	declare @nRegions int, @nRegionTypes int, @nPoints int, @nRows int
	declare @nPosition int, @nCircle int, @nBox int, @nPolygon int, @nPoint int, @nLinestring int, @nRange int
--..................................................................................
	-- Scan string for keywords to identify whether it is STC, WKT or JHU definition

	SET @regionDefinition=RTRIM(LTRIM(UPPER(dbo.fnStr_RemoveMultipleSpaces(@regionDefinition))))
	SET @length=LEN(@regionDefinition)

	-- Region Types
	set @idxPoint=charindex('POINT',@regionDefinition)
	set @idxMultiPoint=charindex('MULTIPOINT',@regionDefinition)
	set @idxLinestring=charindex('LINESTRING',@regionDefinition)
	set @idxMultiLinestring=charindex('MULTILINESTRING',@regionDefinition)
	set @idxPolygon=charindex('POLYGON',@regionDefinition)
	set @idxMultiPolygon=charindex('MULTIPOLYGON',@regionDefinition)
	set @idxGeometryCollection=charindex('GEOMETRYCOLLECTION',@regionDefinition)
	set @idxPosition=charindex('POSITION',@regionDefinition)
	set @idxCircle=charindex('CIRCLE',@regionDefinition)
	set @idxBox=charindex('BOX',@regionDefinition)
	set @idxRange=charindex('RANGE',@regionDefinition)
	-- Reference frames
	set @idxEcliptic=charindex('ECLIPTIC',@regionDefinition)
	set @idxFk4=charindex('FK4',@regionDefinition)
	set @idxFk5=charindex('FK5',@regionDefinition)
	set @idxGalactic=charindex('GALACTIC',@regionDefinition)
	set @idxJ2000=charindex('J2000',@regionDefinition)
	set @idxIcrs=charindex('ICRS',@regionDefinition)
	set @idxUnknownFrame=charindex('UNKNOWNFRAME',@regionDefinition)
	set @idxOther=charindex('OTHER',@regionDefinition)
	set @idxMjd=charindex('MJD',@regionDefinition)
	set @idxGsc1=charindex('GSC1',@regionDefinition)
	set @idxWavelength=charindex('WAVELENGTH',@regionDefinition)
	set @idxBarycenter=charindex('BARYCENTER',@regionDefinition)
	set @idxGeocenter=charindex('GEOCENTER',@regionDefinition)
	set @idxHeliocenter=charindex('HELIOCENTER',@regionDefinition)
	set @idxTopocenter=charindex('TOPOCENTER',@regionDefinition)
	set @idxRelocatable=charindex('RELOCATABLE',@regionDefinition)
	set @idxUnknownRefpos=charindex('UNKNOWNREFPOS',@regionDefinition)
	set @idxLsr=charindex('LSR',@regionDefinition)
	set @idxCartesian1=charindex('CARTESIAN1',@regionDefinition)
	set @idxCartesian2=charindex('CARTESIAN2',@regionDefinition)
	set @idxCartesian3=charindex('CARTESIAN3',@regionDefinition)
	set @idxSpherical2=charindex('SPHERICAL2',@regionDefinition)
	-- punctuation
	set @idxParentheses=charindex('(',@regionDefinition)
	set @idxComma=charindex(',',@regionDefinition)

	-- Simple WKT cases
	if (@idxPoint>0 or @idxMultiPoint>0 or @idxLinestring>0 or @idxMultiLinestring>0 or @idxMultiPolygon>0 or @idxGeometryCollection>0) set @regionSys='WKT'
	-- Simple STC cases
	if (@idxPosition>0 or @idxBox>0 or @idxRange>0) set @regionSys='STC'
	-- Simple JHU cases
	if (@idxJ2000>0) set @regionSys='JHU'
	
	-- Try to resolve overlapping cases (polygon used by WKT, STC, JHU & circle used by STC, JHU) Note that JHU & STC equivalent so use STC as default
	if (@regionSys is null)
	begin
		if (@idxCircle>0) set @regionSys='STC'	
		if (@idxPolygon>0 and @idxComma>0) set @regionSys='WKT' else set @regionSys='STC'
	end

	-- Catch STC cases not handled
	if (@idxUnion>0 or @idxIntersection>0 or @idxNot>0)
	begin
		insert @vertexList 
		select null, @regionSys, 'error', null, null, null, null, null, null
		return
	end
--..................................................................................
-- Transform WKT to same syntax as STC/JHU for processing
-- GEOMETRYCOLLECTION (geography,...)
-- POINT(x y)
-- MULTIPOINT(x1 y1,x2 y2...) or MULTIPOINT((x1 y1)(x2 y2)...)
-- LINESTRING(x1 y1,x2 y2, ...)
-- MULTILINESTRING((x1 y1,x2 y2...),(xa ya,xb yb...), ...)
-- POLYGON((x1 y1,x2 y2...),(xa ya,xb yb...), ...)
-- MULTIPOLYGON(((x1 y1,x2 y2...)),((xa ya,xb yb...), ...))

	if (@regionSys='WKT')
	begin
		set @regionDefinition=dbo.fnStr_replacei(@regionDefinition,'), (','),(')		

		if (@idxGeometryCollection>0)	-- remove GEOMETRYCOLLECTION ()
		begin
			set @idx1=charindex('(',@regionDefinition,@idxGeometryCollection)
			set @idx2=@length-charindex(')',reverse(@regionDefinition))
			set @regionDefinition=substring(@regionDefinition,@idx1+1,@idx2-@idx1)
		end
		if (@idxMultiPoint>0)		-- replace multi with individual
		begin
			set @regionDefinition=dbo.fnStr_replacei(@regionDefinition,'MULTIPOINT',' POINT ')		
			set @regionDefinition=dbo.fnStr_replacei(@regionDefinition,'), (',' POINT ')		
			set @regionDefinition=dbo.fnStr_replacei(@regionDefinition,'),(',' POINT ')		
			set @regionDefinition=dbo.fnStr_replacei(@regionDefinition,',',' POINT ')		
		end
		if (@idxMultiLinestring>0)		-- replace multi with individual
		begin
			set @regionDefinition=dbo.fnStr_replacei(@regionDefinition,'MULTILINESTRING',' LINESTRING ')		
			set @regionDefinition=dbo.fnStr_replacei(@regionDefinition,'),(',' LINESTRING ')		
		end
		if (@idxMultiPolygon>0)		-- replace multi with individual
		begin
			set @regionDefinition=dbo.fnStr_replacei(@regionDefinition,'MULTIPOLYGON',' POLYGON ')		
			set @regionDefinition=dbo.fnStr_replacei(@regionDefinition,')),((',' POLYGON ')		
		end
		set @regionDefinition=dbo.fnStr_replacei(@regionDefinition,'(',' ')
		set @regionDefinition=dbo.fnStr_replacei(@regionDefinition,')',' ')
		set @regionDefinition=dbo.fnStr_replacei(@regionDefinition,',',' ')
	end
--..................................................................................
-- Loop through definition finding regions

	SET @regionDefinition=RTRIM(LTRIM(UPPER(dbo.fnStr_RemoveMultipleSpaces(@regionDefinition))))
	SET @length=LEN(@regionDefinition)
	while (@length>0)
	begin
		-- look for next region
		set @idxBox=charindex('BOX',@regionDefinition)
		set @idxCircle=charindex('CIRCLE',@regionDefinition)
		set @idxLinestring=charindex('LINESTRING',@regionDefinition)
		set @idxPoint=charindex('POINT',@regionDefinition)
		set @idxPolygon=charindex('POLYGON',@regionDefinition)
		set @idxPosition=charindex('POSITION',@regionDefinition)
		set @idxRange=charindex('RANGE',@regionDefinition)
		set @idxRegionStart=@length
		if (@idxBox<@idxRegionStart and @idxBox>0) set @idxRegionStart=@idxBox
		if (@idxCircle<@idxRegionStart and @idxCircle>0) set @idxRegionStart=@idxCircle
		if (@idxLinestring<@idxRegionStart and @idxLinestring>0) set @idxRegionStart=@idxLinestring
		if (@idxPoint<@idxRegionStart and @idxPoint>0) set @idxRegionStart=@idxPoint
		if (@idxPolygon<@idxRegionStart and @idxPolygon>0) set @idxRegionStart=@idxPolygon
		if (@idxPosition<@idxRegionStart and @idxPosition>0) set @idxRegionStart=@idxPosition
		if (@idxRange<@idxRegionStart and @idxRange>0) set @idxRegionStart=@idxRange

		-- exit if no more regions found
		if @idxRegionStart=@length set @length=0

		-- process region
		if @length>0
		begin
			set @regionDefinition=SUBSTRING(@regionDefinition,@idxRegionStart,@length)
			set @length=len(@regionDefinition)
			begin
				set @regionNumber=@regionNumber+1

				-- identify type of region
				IF SUBSTRING(@regionDefinition,1,3)='BOX'			SET @regionType='BOX'
				IF SUBSTRING(@regionDefinition,1,6)='CIRCLE'		SET @regionType='CIRCLE'
				IF SUBSTRING(@regionDefinition,1,10)='LINESTRING'	SET @regionType='LINESTRING'
				IF SUBSTRING(@regionDefinition,1,5)='POINT'			SET @regionType='POINT'
				IF SUBSTRING(@regionDefinition,1,7)='POLYGON'		SET @regionType='POLYGON'
				IF SUBSTRING(@regionDefinition,1,8)='POSITION'		SET @regionType='POSITION'
				IF SUBSTRING(@regionDefinition,1,5)='RANGE'			SET @regionType='RANGE'
				set @idxSpace=charindex(' ',@regionDefinition)
				if @idxSpace>0 set @regionDefinition=substring(@regionDefinition,@idxSpace+1,@length)
				set @length=len(@regionDefinition)

				-- look for next region to find end of this one
				set @idxBox=charindex('BOX',@regionDefinition)
				set @idxCircle=charindex('CIRCLE',@regionDefinition)
				set @idxLinestring=charindex('LINESTRING',@regionDefinition)
				set @idxPoint=charindex('POINT',@regionDefinition)
				set @idxPolygon=charindex('POLYGON',@regionDefinition)
				set @idxPosition=charindex('POSITION',@regionDefinition)
				set @idxRange=charindex('RANGE',@regionDefinition)
				set @idxRegionEnd=@length
				if (@idxBox<@idxRegionEnd and @idxBox>0) set @idxRegionEnd=@idxBox
				if (@idxCircle<@idxRegionEnd and @idxCircle>0) set @idxRegionEnd=@idxCircle
				if (@idxLinestring<@idxRegionEnd and @idxLinestring>0) set @idxRegionEnd=@idxLinestring
				if (@idxPoint<@idxRegionEnd and @idxPoint>0) set @idxRegionEnd=@idxPoint
				if (@idxPolygon<@idxRegionEnd and @idxPolygon>0) set @idxRegionEnd=@idxPolygon
				if (@idxPosition<@idxRegionEnd and @idxPosition>0) set @idxRegionEnd=@idxPosition
				if (@idxRange<@idxRegionEnd and @idxRange>0) set @idxRegionEnd=@idxRange
				if @idxRegionEnd != @length set @idxRegionEnd=@idxRegionEnd-2

				set @regionData=substring(@regionDefinition,1,@idxRegionEnd)
				set @dataLength=len(@regionData)
				set @regionDefinition=substring(@regionDefinition,@idxRegionEnd+1,@length)
				set @length=len(@regionDefinition)
	
				-- check if coordinate system is defined
				set @idxEcliptic=charindex('ECLIPTIC',@regionData)
				set @idxFk4=charindex('FK4',@regionData)
				set @idxFk5=charindex('FK5',@regionData)
				set @idxGalactic=charindex('GALACTIC',@regionData)
				set @idxJ2000=charindex('J2000',@regionData)
				set @idxIcrs=charindex('ICRS',@regionData)
				set @idxUnknownFrame=charindex('UNKNOWNFRAME',@regionData)
				set @idxMjd=charindex('MJD',@regionData)
				set @idxGsc1=charindex('GSC1',@regionData)
				set @idxWavelength=charindex('WAVELENGTH',@regionData)
				set @idxOther=charindex('OTHER',@regionData)
				set @idx=@dataLength
				if (@idxEcliptic<@idx and @idxEcliptic>0) set @idx=@idxEcliptic
				if (@idxFk4<@idx and @idxFk4>0) set @idx=@idxFk4
				if (@idxFk5<@idx and @idxFk5>0) set @idx=@idxFk5
				if (@idxGalactic<@idx and @idxGalactic>0) set @idx=@idxGalactic
				if (@idxGsc1<@idx and @idxGsc1>0) set @idx=@idxGsc1
				if (@idxJ2000<@idx and @idxJ2000>0) set @idx=@idxJ2000
				if (@idxIcrs<@idx and @idxIcrs>0) set @idx=@idxIcrs
				if (@idxMjd<@idx and @idxMjd>0) set @idx=@idxMjd
				if (@idxWavelength<@idx and @idxWavelength>0) set @idx=@idxWavelength
				if (@idxUnknownFrame<@idx and @idxUnknownFrame>0) set @idx=@idxUnknownFrame
				if (@idxOther<@idx and @idxOther>0) set @idx=@idxOther
				set @idxSpace=charindex(' ',@regionData,@idx)
				if @idx=@dataLength set @idx=0
				if @idx>0 
				begin
					set @frameType=substring(@regionData,@idx,@idxSpace-@idx)
					set @regionData=substring(@regionData,@idxSpace+1,@dataLength)
					set @dataLength=len(@regionData)
				end

				-- check if reference position defined
				set @idxBarycenter=charindex('BARYCENTER',@regionData)
				set @idxGeocenter=charindex('GEOCENTER',@regionData)
				set @idxHeliocenter=charindex('HELIOCENTER',@regionData)
				set @idxLsr=charindex('LSR',@regionData)
				set @idxTopocenter=charindex('TOPOCENTER',@regionData)
				set @idxRelocatable=charindex('RELOCATABLE',@regionData)
				set @idxUnknownRefpos=charindex('UNKNOWNREFPOS',@regionData)
				set @idx=@dataLength
				if (@idxBarycenter<@idx and @idxBarycenter>0) set @idx=@idxBarycenter
				if (@idxGeocenter<@idx and @idxGeocenter>0) set @idx=@idxGeocenter
				if (@idxHeliocenter<@idx and @idxHeliocenter>0) set @idx=@idxHeliocenter
				if (@idxLsr<@idx and @idxLsr>0) set @idx=@idxLsr
				if (@idxTopocenter<@idx and @idxTopocenter>0) set @idx=@idxTopocenter
				if (@idxRelocatable<@idx and @idxRelocatable>0) set @idx=@idxRelocatable
				if (@idxUnknownRefpos<@idx and @idxUnknownRefpos>0) set @idx=@idxUnknownRefpos
				set @idxSpace=charindex(' ',@regionData,@idx)
				if @idx=@dataLength set @idx=0
				if @idx>0 
				begin
					set @refPosType=substring(@regionData,@idx,@idxSpace-@idx)
					set @regionData=substring(@regionData,@idxSpace+1,@dataLength)
					set @dataLength=len(@regionData)
				end

				-- check if flavor defined
				set @idxCartesian1=charindex('CARTESIAN1',@regionData)
				set @idxCartesian2=charindex('CARTESIAN2',@regionData)
				set @idxCartesian3=charindex('CARTESIAN3',@regionData)
				set @idxSpherical2=charindex('SPHERICAL2',@regionData)
				set @idx=@dataLength
				if (@idxCartesian1<@idx and @idxCartesian1>0) set @idx=@idxCartesian1
				if (@idxCartesian2<@idx and @idxCartesian2>0) set @idx=@idxCartesian2
				if (@idxCartesian3<@idx and @idxCartesian3>0) set @idx=@idxCartesian3
				if (@idxSpherical2<@idx and @idxSpherical2>0) set @idx=@idxSpherical2
				set @idxSpace=charindex(' ',@regionData,@idx)
				if @idx=@dataLength set @idx=0
				if @idx>0 
				begin
					set @flavorType=substring(@regionData,@idx,@idxSpace-@idx)
					set @regionData=substring(@regionData,@idxSpace+1,@dataLength)
					set @dataLength=len(@regionData)
				end
			
				set @coordSys=@frameType+' '+@refPosType+' '+@flavorType
--..................................................................................
-- Parse data values

				set @pointNumber=0
				while @dataLength>0
				begin
					-- get data in pairs
					set @pointNumber=@pointNumber+1
					set @idxSpace=charindex(' ',@regionData,@idx)
					set @xVal=substring(@regionData,1,@idxSpace-1)
					set @regionData=substring(@regionData,@idxSpace+1,@dataLength)
					set @dataLength=len(@regionData)
					set @idxSpace=charindex(' ',@regionData,@idx)
					if @idxSpace>0 
					begin
						set @yVal=substring(@regionData,1,@idxSpace-1) 
						set @regionData=substring(@regionData,@idxSpace+1,@dataLength)
						set @dataLength=len(@regionData)
					end
					else 
					begin
						set @yVal=@regionData
						set @regionData=''
						set @dataLength=0
					end

					if @regionType in ('POINT','POSITION','RANGE','POLYGON')	-- 2 values, ra/dec or min/max
					begin
						insert @vertexList 
							select @regionNumber, @regionSys, @regionType, @coordSys, @pointNumber, @xVal, @yVal, null, null
					end

					if @regionType in ('BOX','LINESTRING')	-- 4 values , ra/dec/rasize/decsize or ra1/dec1/ra2/dec2
					begin
						if @pointNumber=1 
						begin
							set @xVal1=@xVal
							set @yVal1=@yVal
						end

						if @pointNumber=2 
						begin
							set @xVal2=@xVal
							set @yVal2=@yVal
							insert @vertexList 
								select @regionNumber, @regionSys, @regionType, @coordSys, @pointNumber, @xVal1, @yVal1, @xVal2, @yVal2
						end
					end

					if @regionType='CIRCLE'	-- get radius as third parameter
					begin
						set @xVal2=@regionData
						set @regionData=''
						set @dataLength=0

						insert @vertexList 
							select @regionNumber, @regionSys, @regionType, @coordSys, @pointNumber, @xVal, @yVal, @xVal2, null
					end
				end
--..................................................................................
				-- exit if no more regions found
				if @idxRegionEnd=@length set @length=0
			end
		end
	end
--..................................................................................
	-- validate elements of footprint

	set @nRegions=(select max(regionNumber) from @vertexList)
	set @nRegionTypes=(select count(distinct regionType) from @vertexList)
	set @nPoints=(select count(*) from @vertexList)
	set @nPosition=(select count(regionNumber) from @vertexList where regionType='POSITION')
	set @nCircle=(select count(regionNumber) from @vertexList where regionType='CIRCLE')
	set @nBox=(select count(regionNumber) from @vertexList where regionType='BOX')
	set @nPolygon=(select count(distinct(regionNumber)) from @vertexList where regionType='POLYGON')
	set @nRange=(select count(regionNumber) from @vertexList where regionType='RANGE')
	set @nPoint=(select count(regionNumber) from @vertexList where regionType='POINT')
	set @nLinestring=(select count(regionNumber) from @vertexList where regionType='LINESTRING')
	
	if @nPolygon>1
	begin
		set @idx1=1
		while @idx1<=@nPolygon
		begin
			set @idx2=(select max(pointNumber) from @vertexList where regionNumber=@idx1)
			if @idx2<3 delete from @vertexList where regionNumber=@idx1
			set @idx1=@idx1+1
		end
	end

	RETURN 
END
go
--*****************************************************************************************************************
BEGIN TRY DROP FUNCTION [dbo].[fnStc_convertFootprint] END TRY BEGIN CATCH END CATCH
GO
CREATE FUNCTION [dbo].[fnStc_convertFootprint] (@footprint varchar(max), @type char(3))
RETURNS varchar(max)
AS
BEGIN
	declare @idx int=-1, @length int=-1
	declare @regionNumber int, @regionSys char(3), @regionType varchar(32), @coordSys varchar(48)
	declare @pointNumber int, @xVal1 varchar(max), @yVal1 varchar(max), @xVal2 varchar(max), @yVal2 varchar(max)
	declare @nRegions int, @nRegionTypes int, @nPoints int, @nRows int
	declare @nPosition int, @nCircle int, @nBox int, @nPolygon int, @nPoint int, @nLinestring int, @nRange int
	declare @vertexList TABLE(regionNumber int, regionSys char(3), regionType varchar(32), coordSys varchar(48), 
                              pointNumber int, xVal1 varchar(max), yVal1 varchar(max), xVal2 varchar(max), yVal2 varchar(max))
	declare @location varchar(max), @raMin float, @raMax float, @decMin float, @decMax float, @raCen float, @decCen float
	DECLARE @ra varchar(20), @dec varchar(20), @radius varchar(20), @width varchar(20), @height varchar(20)
	DECLARE @minVal varchar(20), @maxVal varchar(20)
	DECLARE @xpt float, @ypt float, @angle float, @nVertices int, @r float
	declare @eqCoord table(ra float, dec float)
	DECLARE @startPoint varchar(max), @Point varchar(max), @WKT varchar(max)=null

	-- Parse footprint definition
	insert into @vertexList select * from dbo.fnStc_ParseRegionDefinition(@footprint)

	-- validate elements of footprint
	set @nRegions=(select max(regionNumber) from @vertexList)
	set @nRegionTypes=(select count(distinct regionType) from @vertexList)
	set @nPoints=(select count(*) from @vertexList)
	set @nPosition=(select count(regionNumber) from @vertexList where regionType='POSITION')
	set @nCircle=(select count(regionNumber) from @vertexList where regionType='CIRCLE')
	set @nBox=(select count(regionNumber) from @vertexList where regionType='BOX')
	set @nPolygon=(select count(distinct(regionNumber)) from @vertexList where regionType='POLYGON')
	set @nRange=(select count(regionNumber) from @vertexList where regionType='RANGE')
	set @nPoint=(select count(regionNumber) from @vertexList where regionType='POINT')
	set @nLinestring=(select count(regionNumber) from @vertexList where regionType='LINESTRING')

	-- Initialise returned footprint
	if (@type='JHU' or @type='STC') set @footprint=''
	if @type='WKT' 
	begin
		set @footprint=''
	end

	DECLARE cFootprint CURSOR FOR 
		SELECT regionNumber, regionSys, regionType, coordSys, pointNumber, xVal1, yVal1, xVal2, yVal2
		FROM @vertexList

	OPEN cFootprint  
	FETCH NEXT FROM cFootprint INTO @regionNumber, @regionSys, @regionType, @coordSys, @pointNumber, @xVal1, @yVal1, @xVal2, @yVal2  
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		-- Get number of rows for this region
		set @nRows=(select max(pointNumber) from @vertexList where regionNumber=@regionNumber)

		-- Build JHU/STC description
		if (@type='JHU' or @type='STC')
		begin
 			if (@regionType in ('POSITION','POINT'))
 			BEGIN
				-- Two arguments : RA and DEC
				set @footprint=@footprint+'POSITION '+@coordSys+' '+@xVal1+' '+@yVal1
 			END

			if (@regionType='BOX')
 			BEGIN
				-- Four arguments : RA center, DEC center, RA width, DEC height		
				set @footprint=@footprint+'POSITION '+@coordSys+' '+@xVal1+' '+@yVal1+' '+@xVal2+' '+@yVal2
 			END		

			IF (@regionType='CIRCLE') 
			BEGIN
				-- Three arguments : RA center, DEC center, Radius
				set @footprint=@footprint+'CIRCLE '+@coordSys+' '+@xVal1+' '+@yVal1+' '+@xVal2
			END		

 			if (@regionType='LINESTRING')
 			BEGIN
				-- Does not map to STC
				---set @footprint=@footprint+'LINESTRING unsupported'
				set @footprint=@footprint+'RANGE '+@coordSys+' '+@xVal1+' '+@xVal2
 			END

			if (@regionType='RANGE')
 			BEGIN
				-- Four arguments in Two arguments out : minVal maxVal	
				set @footprint=@footprint+'RANGE '+@coordSys+' '+@xVal1+' '+@xVal2
 			END	
				
			IF (@regionType = 'POLYGON')
			BEGIN
				-- Two arguments : RA and DEC
				set @ra=@xVal1
				set @dec=@yVal1

				if @pointNumber=1 
				begin
					SET @location=@xVal1+' '+@yVal1
					set @startPoint=@location
				end
				if @pointNumber>1
				begin
					SET @location=@location+' '+@xVal1+' '+@yVal1
				end
				if @pointNumber=@nRows set @footprint=@footprint+'POLYGON '+@coordSys+' '+@location+' '+@startPoint
			END

			if (@regionNumber<@nRegions and @pointNumber=@nRows) set @footprint=@footprint+' ' 
		end

		-- Build WKT description
		if @type='WKT'
		begin
 			if (@regionType='POSITION')
 			BEGIN
				-- Two arguments : RA and DEC
				set @ra=@xVal1
				set @dec=@yVal1

				SET @location=LTRIM(STR(@ra,12,8))+' '+LTRIM(STR(@dec,12,8))
				set @footprint=@footprint+'POINT('+@location+')'
 			END

			if (@regionType='BOX')
 			BEGIN
				-- Four arguments : RA center, DEC center, RA width, DEC height

				-- Compute corner coordinates
				SET @ramin=CAST(@xVal1 as float)-CAST(@xVal2 as float)/2.0
				SET @ramax=CAST(@xVal1 as float)+CAST(@xVal2 as float)/2.0
				SET @decmin=CAST(@yVal1 as float)-CAST(@yVal2 as float)/2.0
				SET @decmax=CAST(@yVal1 as float)+CAST(@yVal2 as float)/2.0
			
				-- Build Box as Polygon
				SET @location=      '('+LTRIM(STR(@ramax,12,8))+' '+LTRIM(STR(@decmin,12,8))+','
				SET @location=@location+LTRIM(STR(@ramax,12,8))+' '+LTRIM(STR(@decmax,12,8))+','
				SET @location=@location+LTRIM(STR(@ramin,12,8))+' '+LTRIM(STR(@decmax,12,8))+','
				SET @location=@location+LTRIM(STR(@ramin,12,8))+' '+LTRIM(STR(@decmin,12,8))+','
				SET @location=@location+LTRIM(STR(@ramax,12,8))+' '+LTRIM(STR(@decmin,12,8))+')'
				set @footprint=@footprint+'POLYGON('+@location+')'
 			END		
				
			IF (@regionType='CIRCLE') 
			BEGIN
				-- Three arguments : RA center, DEC center, Radius
				set @raCen=@xVal1
				set @decCen=@yVal1
				set @radius=@xVal2

				-- Build circle as polygon with n vertices (15 < n < 60 depending on radius)
				set @r=cast(@radius as float)*3600.0	-- converting from degrees to arcsec
				SET @nVertices=(select iif (@r/60. < 15,15,floor(@r/60)))
				SET @location='('
				SET @idx=0
				WHILE @idx < @nVertices
				BEGIN
					SET @angle=RADIANS(@idx*360.0/@nVertices)				
					SET @ypt=@r*SIN(@angle)
					SET @xpt=(@r*COS(@angle))--/COS(RADIANS(@ypt)))
					delete from @eqCoord
					insert into @eqCoord select * from dbo.fnAstrom_TranStdEq(@xpt,@ypt,@raCen,@decCen)
					SET @Point=(select LTRIM(STR(ra,12,8))+' '+LTRIM(STR(dec,12,8)) from @eqCoord)
					IF (@idx=0) SET @startPoint=@Point
					SET @location=@location+@Point+','
					SET @idx=@idx+1
				END
				SET @location=@location+@startPoint+')'	
				set @footprint=@footprint+'POLYGON('+@location+')'	
			END		

			IF (@regionType = 'POLYGON')
			BEGIN
				-- Two arguments : RA and DEC
				set @ra=@xVal1
				set @dec=@yVal1

				if @pointNumber=1 
				begin
					SET @location=LTRIM(STR(@ra,12,8))+' '+LTRIM(STR(@dec,12,8))
					set @startPoint=@location
				end
				if @pointNumber>1
				begin
					SET @location=@location+','+LTRIM(STR(@ra,12,8))+' '+LTRIM(STR(@dec,12,8))
				end
				if @pointNumber=@nRows set @footprint=@footprint+'POLYGON(('+@location+','+@startPoint+'))'
			END

			IF (@regionType = 'RANGE')
 			BEGIN
				-- 2 arguments : minValue maxValue
				SET @minVal=@xVal1
				SET @maxVal=@yVal1
	
				-- Build Range as endpoints of line
				SET @location=LTRIM(@minVal)+' 0,'+LTRIM(@maxVal)+' 0'
				set @footprint=@footprint+'LINESTRING('+@location+')'
 			END		

			if (@regionNumber<@nRegions and @pointNumber=@nRows) set @footprint=@footprint+',' 

		end
	FETCH NEXT FROM cFootprint INTO @regionNumber, @regionSys, @regionType, @coordSys, @pointNumber, @xVal1, @yVal1, @xVal2, @yVal2  
	END  

	CLOSE cFootprint  
	DEALLOCATE cFootprint


	-- Additional WKT processing
	if @type='WKT'
	begin
		-- consolidate MULTI
		if @nPoint>1 or @nPosition>1
		begin
			set @footprint=dbo.fnStr_replacei(@footprint,'POINT','')
			set @footprint=dbo.fnStr_replacei(@footprint,'(','')
			set @footprint=dbo.fnStr_replacei(@footprint,')','')
			set @footprint='MULTIPOINT('+@footprint+')'
		end
		if @nPolygon>1
		begin
			set @footprint=dbo.fnStr_replacei(@footprint,'POLYGON','')
			set @footprint='MULTIPOLYGON('+@footprint+')'
		end
		if @nLinestring>1 or @nRange>1
		begin
			set @footprint=dbo.fnStr_replacei(@footprint,'LINESTRING','')
			set @footprint='MULTILINESTRING('+@footprint+')'
		end

		if @nRegionTypes>1
		begin
			set @footprint='GEOMETRYCOLLECTION('+@footprint+')'
		end
	end

	SET @footprint=RTRIM(LTRIM(UPPER(dbo.fnStr_RemoveMultipleSpaces(@footprint))))
	if @footprint='' set @footprint=null
	return @footprint
END
go
------------------------------------------------------------------------------------------------------
begin try drop function fnStc_convertSTCStoLine end try begin catch end catch
go
CREATE FUNCTION fnStc_convertSTCStoLine(@STCS varchar(max))
returns geometry as
begin
	-- Declare variables
	DECLARE @WKT varchar(max), @line geometry 

	set @WKT=dbo.fnStc_convertFootprint(@STCS,'WKT')
	if @WKT is not null set @line=geometry::Parse(@WKT).MakeValid()
	return @line
end
go
--select dbo.fnStc_convertSTCStoLine('Range 10 20 Range 30 40 Range 50 60')
------------------------------------------------------------------------------------------------------
begin try drop function fnStc_convertSTCStoSpatial end try begin catch end catch
go
CREATE FUNCTION fnStc_convertSTCStoSpatial(@STCS varchar(max), @srid int)
returns geography as
begin
	-- Declare variables
	DECLARE @WKT varchar(max), @spatial geography , @invertedspatial geography, @area float
	DECLARE @geom geometry

	set @WKT=dbo.fnStc_convertFootprint(@STCS,'WKT')
	if @WKT is not null set @spatial=geography::STGeomFromText(@WKT,@srid).MakeValid()

	-- Check to see if polygon vertices are 'backwards'
	if @spatial.EnvelopeAngle() >= 90
	begin
		set @spatial=@spatial.ReorientObject()
	end
	return @spatial
end
go
--select dbo.fnStc_convertSTCStoSpatial('CIRCLE ICRS 254.58755449  34.21313021   0.00069444',4326)
--select dbo.fnStc_convertSTCStoSpatial('CIRCLE ICRS 254.58755449  34.21313021   0.00069444',104001)
--select dbo.fnStc_ConvertSTCStoSpatial('CIRCLE 191.91549725  66.64332144 0.625',4326)
--select dbo.fnStc_convertSTCStoSpatial('POLYGON ((129.22981692 7.97845031, 129.20117354 7.95365949, 129.2235339 7.92776646, 129.25289069 7.95318849, 129.22981692 7.97845031))',4326)
--select dbo.fnStc_convertSTCStoSpatial('POLYGON 180.428742 -18.893042 180.461245 -18.844614 180.488081 -18.858382 180.455582 -18.906816 180.428742 -18.893042',104001)
--select dbo.fnStc_convertSTCStoSpatial('POLYGON 180.428742 -18.893042 180.455582 -18.906816 180.488081 -18.858382 180.461245 -18.84461 180.428742 -18.893042',4326)
------------------------------------------------------------------------------------------------------
begin try drop function fnStc_convertSpatialtoSTCS end try begin catch end catch
go
CREATE FUNCTION fnStc_convertSpatialtoSTCS(@spatial geography)
returns varchar(max) as
begin
	-- Declare variables
	DECLARE @WKT varchar(max), @STCS varchar(max)

	set @WKT=@spatial.STAsText()
	if @WKT is not null set @STCS=dbo.fnStc_convertFootprint(@WKT,'STC')

	return @STCS
end
go
------------------------------------------------------------------------------------------------------
begin try drop function fnStc_convertLinetoSTCS end try begin catch end catch
go
CREATE FUNCTION fnStc_convertLinetoSTCS(@line geometry)
returns varchar(max) as
begin
	-- Declare variables
	DECLARE @WKT varchar(max), @STCS varchar(max)

	set @WKT=@line.STAsText()
	if @WKT is not null set @STCS=dbo.fnStc_convertFootprint(@WKT,'STC')
	return @STCS
end
go
--declare @line geometry
--set @line=dbo.fnStc_convertSTCStoLine('Range 10 20 Range 30 40 Range 50 60')
--select dbo.fnStc_convertLinetoSTCS(@line)
------------------------------------------------------------------------------------------------------
begin try drop function fnStc_convertWKTtoSpatial end try begin catch end catch
go
CREATE FUNCTION fnStc_convertWKTtoSpatial(@WKT varchar(max), @srid int)
returns geography as
begin
	-- Declare variables
	DECLARE @spatial geography 

	if @WKT is not null set @spatial=geography::STGeomFromText(@WKT,@srid).MakeValid()
	return @spatial
end
go
--select dbo.fnStc_convertWKTtoSpatial('MULTIPOLYGON(((189.05848996 25.99737649,189.05837800 25.99747000,189.05071400 25.99006100,189.05082654 25.98996702,189.05895700 25.98317700,189.05906345 25.98327997,189.05917600 25.98318600,189.05928145 25.98328799,189.05939400 25.98319400,189.06705500 25.99060400,189.05881500 25.99748800,189.05870849 25.99738504,189.05859600 25.99747900,189.05848996 25.99737649)),((189.07671668 25.96876919,189.07661200 25.96866800,189.08485300 25.96178400,189.09251400 25.96919200,189.09239938 25.96928781,189.09250300 25.96938800,189.09238891 25.96948337,189.09249300 25.96958400,189.08425500 25.97646900,189.08404770 25.97626864,189.07659100 25.96906100,189.07670566 25.96896520,189.07660200 25.96886500,189.07671668 25.96876919)))',4326)
go
------------------------------------------------------------------------------------------------------

/*
select dbo.fnStc_convertFootprint('Position GALACTIC 10 20','WKT')
select dbo.fnStc_convertFootprint('Box CARTESIAN2 3 3 2 2','WKT')
select dbo.fnStc_convertFootprint('Range MJD CARTESIAN1 10 20','WKT')
select dbo.fnStc_convertFootprint('Polygon ICRS 1 4 1.5 3.5 2 4 2 5 1 5','WKT')
select dbo.fnStc_convertFootprint('CIRCLE ICRS 254.58755449  34.21313021   0.00069444','WKT')
select dbo.fnStc_convertFootprint('Position GALACTIC 10 20 Position 20 30','WKT')
select dbo.fnStc_convertFootprint('Polygon ICRS 1 4 1.5 3.5 2 4 2 5 1 5 Polygon FK5 11 4 11.5 3.5 12 4 12 5 11 5 Polygon J2000 6 -1 6.5 -1.5 7 -1 7 0 5 0','WKT')

declare @test varchar(max)
--STC Examples
set @test='CIRCLE ICRS 254.58755449  34.21313021   0.00069444'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='POLYGON ICRS 279.10939000 -23.89704300 279.11663400 -23.88939700 279.10827600 -23.88277600 279.10102800 -23.89042200 279.10939000 -23.89704300 POLYGON ICRS 279.07973200 -23.88956500 279.07248300 -23.89720900 279.08084300 -23.90383200 279.08809000 -23.89618800 279.07973200 -23.88956500 POLYGON ICRS 279.09961300 -23.92899300 279.10685900 -23.92134800 279.09849900 -23.91472600 279.09125000 -23.92237100 279.09961300 -23.92899300'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='Position GALACTIC 10 20'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='Position GALACTIC 10 20 Position 20 30'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='Box CARTESIAN2 3 3 2 2'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='Circle ICRS GEOCENTER 10 20 0.5'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='Polygon ICRS 1 4 1.5 3.5 2 4 2 5 1 5'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='Polygon ICRS 1 4 1.5 3.5 2 4 2 5 1 5 Polygon ICRS 11 4 11.5 3.5 12 4 12 5 11 5'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='Polygon ICRS 1 4 1.5 3.5 2 4 2 5 1 5 Polygon FK5 11 4 11.5 3.5 12 4 12 5 11 5 Polygon J2000 6 -1 6.5 -1.5 7 -1 7 0 5 0'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='Range MJD CARTESIAN1 10 20'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='Range WAVELENGTH 1000 2000 Range 3000 4000'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')

--WKT Examples
set @test='MULTIPOLYGON(((279.10939000 -23.89704300,279.11663400 -23.88939700,279.10827600 -23.88277600,279.10102800 -23.89042200,279.10939000 -23.89704300)),((279.07973200 -23.88956500,279.07248300 -23.89720900,279.08084300 -23.90383200,279.08809000 -23.89618800,279.07973200 -23.88956500)),((279.09961300 -23.92899300,279.10685900 -23.92134800,279.09849900 -23.91472600,279.09125000 -23.92237100,279.09961300 -23.92899300)))'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='POLYGON((1.00000000 4.00000000,1.50000000 3.50000000,2.00000000 4.00000000,2.00000000 5.00000000,1.00000000 5.00000000,1.00000000 4.00000000))'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='MULTIPOLYGON(((1.00000000 4.00000000,1.50000000 3.50000000,2.00000000 4.00000000,2.00000000 5.00000000,1.00000000 5.00000000,1.00000000 4.00000000)),((11.00000000 4.00000000,11.50000000 3.50000000,12.00000000 4.00000000,12.00000000 5.00000000,11.00000000 5.00000000,11.00000000 4.00000000)))'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='GEOMETRYCOLLECTION (LINESTRING (-149.0755292999998 54.392134500000083, -149.04791489999991 54.34992039999986), POLYGON ((-149.04810560000004 54.3496663, -149.04813184999992 54.349706950000083, -149.04810500000019 54.349713999999992, -149.0755292999998 54.392134500000083, -149.0755701300001 54.39212377999997, -149.07557940000012 54.392138099999869, -149.07560564999989 54.392131210000031, -149.11109650000003 54.382809899999884, -149.11107017 54.3827692800001, -149.11109710000014 54.382762199999881, -149.08364229999989 54.340349700000012, -149.08360149999993 54.340360420000145, -149.08359229999996 54.34034620000002, -149.04814579999979 54.34965575, -149.04810560000004 54.3496663)), POLYGON ((-149.0128136 54.359096600000015, -149.03958640000005 54.401391799999864, -149.07471790000011 54.39220780000003, -149.04791489999991 54.34992039999986, -149.0128136 54.359096600000015)))'
select * from dbo.fnStc_ParseRegionDefinition(@test)

--JHU Examples
set @test='Polygon J2000 53.24913310 -9.42395480 53.19412010 -9.43801150 53.20355810 -9.46406650 53.25857490 -9.45000830 Polygon J2000  53.26856470 -9.47729550 53.25900450 -9.45027110 53.20353490 -9.46522910 53.21309120 -9.49225500'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='Polygon J2000 179.43465060 55.50034880 179.39915230 55.48134740 179.46032150 55.43730430 179.49580960 55.45628800 Polygon J2000  179.47179760 55.52032890 179.43477490 55.50084250 179.49770410 55.45673330 179.53471630 55.47620080'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
set @test='Polygon J2000 201.38569396 -47.59202260 201.36939200 -47.59437700 201.37626800 -47.61600700 201.40836800 -47.61136600 201.40834159 -47.61128290 201.43742900 -47.60687600 201.43108164 -47.58782072 201.43136300 -47.58777700 201.42400400 -47.56622900 201.42390130 -47.56624496 201.39544020 -47.57066451 201.39413580 -47.57086687 201.39202700 -47.57119400 201.39577023 -47.58216633 201.39773500 -47.58187400 201.38308400 -47.58405200 Polygon J2000  201.40149600 -47.58973800 201.40147278 -47.58966490'
select * from dbo.fnStc_ParseRegionDefinition(@test)
select dbo.fnStc_convertFootprint(@test,'STC')
go
-- Test stcs queries
select * from GSC233plus.dbo.GSC23publicVOview as X, GSC233plus.dbo.fnSpatial_SearchSTCSFootprint('CIRCLE ICRS 254.58755449  34.21313021   0.1') as N where X.objid=N.objid 
select * from GSC233plus.dbo.GSC23publicVOview as X, GSC233plus.dbo.fnSpatial_SearchSTCSFootprint('POLYGON 180.428742 -18.893042 180.455582 -18.906816 180.488081 -18.858382 180.461245 -18.84461 180.428742 -18.893042') as N where X.objid=N.objid 

*/
-- cleanup old versions
begin try drop function ExtractRegionsFromSTCS end try begin catch end catch
begin try drop function ExtractRegionsFromWKT end try begin catch end catch
begin try drop function ParseRegionDefinition end try begin catch end catch
begin try drop function dbo.convertFootprint end try begin catch end catch
begin try drop function dbo.ConvertJHUtoWKT end try begin catch end catch
begin try drop function dbo.convertSpatialtoSTCS end try begin catch end catch
begin try drop function dbo.convertSTCStoLine end try begin catch end catch
begin try drop function dbo.convertSTCStoSpatial end try begin catch end catch
begin try drop function dbo.ConvertSTCStoWKT end try begin catch end catch
begin try drop function dbo.convertWKTtoSpatial end try begin catch end catch
begin try drop function dbo.ConvertWKTtoSTCS end try begin catch end catch
begin try drop function dbo.ExtractDataValueFromRegion end try begin catch end catch

------------------------------------------------------------------------------------------------------
