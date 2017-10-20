DROP FUNCTION IF EXISTS [dbo].[fnCaomPlaneSpatial_SearchSTCSFootprint]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[fnCaomPlaneSpatial_SearchSTCSFootprint](@stcs nvarchar(max))
RETURNS @CaomPlane TABLE 
(
	[planeID] [bigint] NOT NULL,
	[obsID] [bigint] NOT NULL,
	[productID] [varchar](256) NOT NULL,
	[creatorID] [varchar](256) NULL,
	[metaDataRights] [varchar](32) NULL,
	[metaRelease] [datetime] NULL,
	[dataRights] [varchar](32) NULL,
	[dataRelease] [datetime] NULL,
	[dataProductType] [varchar](32) NULL,
	[calibrationLevel] [int] NULL,
	[previewURI] [varchar](1024) NULL,
	[productURI] [varchar](1024) NULL,
	[prvName] [varchar](256) NULL,
	[prvReference] [varchar](max) NULL,
	[prvVersion] [varchar](256) NULL,
	[prvProject] [varchar](256) NULL,
	[prvProducer] [varchar](256) NULL,
	[prvRunID] [varchar](max) NULL,
	[prvLastExecuted] [datetime] NULL,
	[prvKeywords] [varchar](max) NULL,
	[prvInputs] [varchar](max) NULL,
	[posLocationRA] [float] NULL,
	[posLocationDec] [float] NULL,
	[posBounds] [geography] NULL,
	[posBoundsSTCS] [varchar](max) NULL,
	[posDimension1] [int] NULL,
	[posDimension2] [int] NULL,
	[posResolution] [float] NULL,
	[posSampleSize] [float] NULL,
	[posTimeDependant] [bit] NULL,
	[enrValue] [float] NULL,
	[enrMin] [float] NULL,
	[enrMax] [float] NULL,
	[enrBounds] [geometry] NULL,
	[enrBoundsSTCS] [varchar](max) NULL,
	[enrDimension] [int] NULL,
	[enrResolution] [float] NULL,
	[enrSampleSize] [float] NULL,
	[enrResolvingPower] [float] NULL,
	[enrBandpassName] [varchar](256) NULL,
	[enrEMBand] [varchar](32) NULL,
	[enrTransition] [varchar](256) NULL,
	[enrTransitionSpecies] [varchar](256) NULL,
	[enrRestWavelength] [float] NULL,
	[timValue] [float] NULL,
	[timMin] [float] NULL,
	[timMax] [float] NULL,
	[timBounds] [geometry] NULL,
	[timBoundsSTCS] [varchar](max) NULL,
	[timDimension] [int] NULL,
	[timResolution] [float] NULL,
	[timSampleSize] [float] NULL,
	[timExposure] [float] NULL,
	[plrDimension] [int] NULL,
	[plrState] [varchar](2) NULL,
	[dqFlag] [varchar](32) NULL,
	[mtrSourceNumberDensity] [float] NULL,
	[mtrBackground] [float] NULL,
	[mtrBackgroundStdDev] [float] NULL,
	[mtrFluxDensityLimit] [float] NULL,
	[mtrMagLimit] [float] NULL,
	[recordCreated] [datetime] NOT NULL,
	[lastModified] [datetime] NULL,
	[maxLastModified] [datetime] NULL,
	[metaChecksum] [varchar](64) NULL,
	[accMetaChecksum] [varchar](64) NULL,
	[id] [uniqueidentifier] NULL,
	[recordModified] [datetime] NULL
)
AS BEGIN
	-- Declare variables
	DECLARE @footprintSearch geography
	DECLARE @neighbours table(objID bigint)
	-- Create spatial footprint for search
	SET @footprintSearch=(select dbo.fnStc_convertSTCStoSpatial(@stcs,104001))
	-- Create table of objects intersecting box
	INSERT @neighbours SELECT objID FROM objectCoords WHERE Spatial.STIntersects(@footprintSearch)=1 
	insert @CaomPlane select 
		p.planeID, p.obsID, p.productID, p.creatorID, p.metaDataRights, p.metaRelease, p.dataRights, p.dataRelease, p.dataProductType, p.calibrationLevel,
		p.previewURI, p.productURI, p.prvName, p.prvReference, p.prvVersion, p.prvProject, p.prvProducer, p.prvRunID, p.prvLastExecuted, p.prvKeywords,
		p.prvInputs, p.posLocationRA, p.posLocationDec, p.posBounds, p.posBoundsSTCS, p.posDimension1, p.posDimension2, p.posResolution, p.posSampleSize, p.posTimeDependant,
		p.enrValue, p.enrMin, p.enrMax, p.enrBounds, p.enrBoundsSTCS, p.enrDimension, p.enrResolution, p.enrSampleSize, p.enrResolvingPower, p.enrBandpassName,
		p.enrEMBand, p.enrTransition, p.enrTransitionSpecies, p.enrRestWavelength, p.timValue, p.timMin, p.timMax, p.timBounds, p.timBoundsSTCS, p.timDimension,
		p.timResolution, p.timSampleSize, p.timExposure, p.plrDimension, p.plrState, p.dqFlag, p.mtrSourceNumberDensity, p.mtrBackground, p.mtrBackgroundStdDev, p.mtrFluxDensityLimit,
		p.mtrMagLimit, p.recordCreated, p.lastModified, p.maxLastModified, p.metaChecksum, p.accMetaChecksum, p.id, p.recordModified
	from @neighbours N join CaomPlane p on p.planeID=N.objID 
	RETURN 
END
GO


