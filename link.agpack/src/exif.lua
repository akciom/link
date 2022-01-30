-- Copyright 2022 - Scott Smith
local ffi = require "ffi"

local log = require "utils.logging"({hal = hal})
local sfmt = string.format

local bit = require "bit"
local band, bor, lshift, rshift
	= bit.band, bit.bor, bit.lshift, bit.rshift

if not hal_defined.exif_function then
hal_defined.exif_function = true
ffi.cdef[[
	typedef unsigned char  uint8_t;
	typedef char *         string;
	typedef unsigned short uint16_t;
	typedef unsigned long  uint32_t;
	typedef struct u_rational {
		uint32_t numerator;
		uint32_t denominator;
	} * ufrac;
	typedef char *         unknown;
	typedef signed char    int8_t;
	typedef signed short   int16_t;
	typedef signed long    int32_t;
	typedef struct i_rational {
		int32_t numerator;
		int32_t denominator;
	} * ifrac;

	struct marker_header {
		uint16_t marker;
		uint16_t size;
	};


	struct exif_header {
		uint16_t _pad; //pad necessary for proper alignment
		uint16_t marker;
		uint16_t size;
		char magic[6];
		uint16_t endianess;
		uint16_t tag_mark;
		uint32_t ifd_offset;
	};

	struct ifd_entry {
		uint16_t tag;
		uint16_t format;
		uint32_t number;
		uint32_t data_off;
	};
]]
end

local function swap16(num)
	num = band(num, 0xffff)
	local res = bor(lshift(band(num, 0xff), 8), rshift(num, 8))
	--log.swap("16-bit:     %04x →     %04x", num, res)
	return res
end

local function swap32(num)
	num = band(num, 0xffffffff)
	local res = bor(rshift(band(num, 0xff000000), 24),
			   rshift(band(num, 0x00ff0000),  8),
			   lshift(band(num, 0x0000ff00),  8),
			   lshift(num, 24)
		   )
	--log.swap("32-bit: %d → %d", num, res)
	--log.swap("32-bit: %08x → %08x", num, res)
	return res
end

local function noswap(num)
	--log.swap("none: %8x", num)
	return num
end

local ifd_tags = { --{{{
	[0x000b] = "Image.ProcessingSoftware",
	[0x00fe] = "Image.NewSubfileType",
	[0x00ff] = "Image.SubfileType",
	[0x0100] = "Image.ImageWidth",
	[0x0101] = "Image.ImageLength",
	[0x0102] = "Image.BitsPerSample",
	[0x0103] = "Image.Compression",
	[0x0106] = "Image.PhotometricInterpretation",
	[0x0107] = "Image.Thresholding",
	[0x0108] = "Image.CellWidth",
	[0x0109] = "Image.CellLength",
	[0x010a] = "Image.FillOrder",
	[0x010d] = "Image.DocumentName",
	[0x010e] = "Image.ImageDescription",
	[0x010f] = "Image.Make",
	[0x0110] = "Image.Model",
	[0x0111] = "Image.StripOffsets",
	[0x0112] = "Image.Orientation",
	[0x0115] = "Image.SamplesPerPixel",
	[0x0116] = "Image.RowsPerStrip",
	[0x0117] = "Image.StripByteCounts",
	[0x011a] = "Image.XResolution",
	[0x011b] = "Image.YResolution",
	[0x011c] = "Image.PlanarConfiguration",
	[0x0122] = "Image.GrayResponseUnit",
	[0x0123] = "Image.GrayResponseCurve",
	[0x0124] = "Image.T4Options",
	[0x0125] = "Image.T6Options",
	[0x0128] = "Image.ResolutionUnit",
	[0x0129] = "Image.PageNumber",
	[0x012d] = "Image.TransferFunction",
	[0x0131] = "Image.Software",
	[0x0132] = "Image.DateTime",
	[0x013b] = "Image.Artist",
	[0x013c] = "Image.HostComputer",
	[0x013d] = "Image.Predictor",
	[0x013e] = "Image.WhitePoint",
	[0x013f] = "Image.PrimaryChromaticities",
	[0x0140] = "Image.ColorMap",
	[0x0141] = "Image.HalftoneHints",
	[0x0142] = "Image.TileWidth",
	[0x0143] = "Image.TileLength",
	[0x0144] = "Image.TileOffsets",
	[0x0145] = "Image.TileByteCounts",
	[0x014a] = "Image.SubIFDs",
	[0x014c] = "Image.InkSet",
	[0x014d] = "Image.InkNames",
	[0x014e] = "Image.NumberOfInks",
	[0x0150] = "Image.DotRange",
	[0x0151] = "Image.TargetPrinter",
	[0x0152] = "Image.ExtraSamples",
	[0x0153] = "Image.SampleFormat",
	[0x0154] = "Image.SMinSampleValue",
	[0x0155] = "Image.SMaxSampleValue",
	[0x0156] = "Image.TransferRange",
	[0x0157] = "Image.ClipPath",
	[0x0158] = "Image.XClipPathUnits",
	[0x0159] = "Image.YClipPathUnits",
	[0x015a] = "Image.Indexed",
	[0x015b] = "Image.JPEGTables",
	[0x015f] = "Image.OPIProxy",
	[0x0200] = "Image.JPEGProc",
	[0x0201] = "Image.JPEGInterchangeFormat",
	[0x0202] = "Image.JPEGInterchangeFormatLength",
	[0x0203] = "Image.JPEGRestartInterval",
	[0x0205] = "Image.JPEGLosslessPredictors",
	[0x0206] = "Image.JPEGPointTransforms",
	[0x0207] = "Image.JPEGQTables",
	[0x0208] = "Image.JPEGDCTables",
	[0x0209] = "Image.JPEGACTables",
	[0x0211] = "Image.YCbCrCoefficients",
	[0x0212] = "Image.YCbCrSubSampling",
	[0x0213] = "Image.YCbCrPositioning",
	[0x0214] = "Image.ReferenceBlackWhite",
	[0x02bc] = "Image.XMLPacket",
	[0x4746] = "Image.Rating",
	[0x4749] = "Image.RatingPercent",
	[0x7032] = "Image.VignettingCorrParams",
	[0x7035] = "Image.ChromaticAberrationCorrParams",
	[0x7037] = "Image.DistortionCorrParams",
	[0x800d] = "Image.ImageID",
	[0x828d] = "Image.CFARepeatPatternDim",
	[0x828e] = "Image.CFAPattern",
	[0x828f] = "Image.BatteryLevel",
	[0x8298] = "Image.Copyright",
	[0x829a] = "Image.ExposureTime",
	[0x829d] = "Image.FNumber",
	[0x83bb] = "Image.IPTCNAA",
	[0x8649] = "Image.ImageResources",
	[0x8769] = "Image.ExifTag",
	[0x8773] = "Image.InterColorProfile",
	[0x8822] = "Image.ExposureProgram",
	[0x8824] = "Image.SpectralSensitivity",
	[0x8825] = "Image.GPSTag",
	[0x8827] = "Image.ISOSpeedRatings",
	[0x8828] = "Image.OECF",
	[0x8829] = "Image.Interlace",
	[0x882a] = "Image.TimeZoneOffset",
	[0x882b] = "Image.SelfTimerMode",
	[0x9003] = "Image.DateTimeOriginal",
	[0x9102] = "Image.CompressedBitsPerPixel",
	[0x9201] = "Image.ShutterSpeedValue",
	[0x9202] = "Image.ApertureValue",
	[0x9203] = "Image.BrightnessValue",
	[0x9204] = "Image.ExposureBiasValue",
	[0x9205] = "Image.MaxApertureValue",
	[0x9206] = "Image.SubjectDistance",
	[0x9207] = "Image.MeteringMode",
	[0x9208] = "Image.LightSource",
	[0x9209] = "Image.Flash",
	[0x920a] = "Image.FocalLength",
	[0x920b] = "Image.FlashEnergy",
	[0x920c] = "Image.SpatialFrequencyResponse",
	[0x920d] = "Image.Noise",
	[0x920e] = "Image.FocalPlaneXResolution",
	[0x920f] = "Image.FocalPlaneYResolution",
	[0x9210] = "Image.FocalPlaneResolutionUnit",
	[0x9211] = "Image.ImageNumber",
	[0x9212] = "Image.SecurityClassification",
	[0x9213] = "Image.ImageHistory",
	[0x9214] = "Image.SubjectLocation",
	[0x9215] = "Image.ExposureIndex",
	[0x9216] = "Image.TIFFEPStandardID",
	[0x9217] = "Image.SensingMethod",
	[0x9c9b] = "Image.XPTitle",
	[0x9c9c] = "Image.XPComment",
	[0x9c9d] = "Image.XPAuthor",
	[0x9c9e] = "Image.XPKeywords",
	[0x9c9f] = "Image.XPSubject",
	[0xc4a5] = "Image.PrintImageMatching",
	[0xc612] = "Image.DNGVersion",
	[0xc613] = "Image.DNGBackwardVersion",
	[0xc614] = "Image.UniqueCameraModel",
	[0xc615] = "Image.LocalizedCameraModel",
	[0xc616] = "Image.CFAPlaneColor",
	[0xc617] = "Image.CFALayout",
	[0xc618] = "Image.LinearizationTable",
	[0xc619] = "Image.BlackLevelRepeatDim",
	[0xc61a] = "Image.BlackLevel",
	[0xc61b] = "Image.BlackLevelDeltaH",
	[0xc61c] = "Image.BlackLevelDeltaV",
	[0xc61d] = "Image.WhiteLevel",
	[0xc61e] = "Image.DefaultScale",
	[0xc61f] = "Image.DefaultCropOrigin",
	[0xc620] = "Image.DefaultCropSize",
	[0xc621] = "Image.ColorMatrix1",
	[0xc622] = "Image.ColorMatrix2",
	[0xc623] = "Image.CameraCalibration1",
	[0xc624] = "Image.CameraCalibration2",
	[0xc625] = "Image.ReductionMatrix1",
	[0xc626] = "Image.ReductionMatrix2",
	[0xc627] = "Image.AnalogBalance",
	[0xc628] = "Image.AsShotNeutral",
	[0xc629] = "Image.AsShotWhiteXY",
	[0xc62a] = "Image.BaselineExposure",
	[0xc62b] = "Image.BaselineNoise",
	[0xc62c] = "Image.BaselineSharpness",
	[0xc62d] = "Image.BayerGreenSplit",
	[0xc62e] = "Image.LinearResponseLimit",
	[0xc62f] = "Image.CameraSerialNumber",
	[0xc630] = "Image.LensInfo",
	[0xc631] = "Image.ChromaBlurRadius",
	[0xc632] = "Image.AntiAliasStrength",
	[0xc633] = "Image.ShadowScale",
	[0xc634] = "Image.DNGPrivateData",
	[0xc635] = "Image.MakerNoteSafety",
	[0xc65a] = "Image.CalibrationIlluminant1",
	[0xc65b] = "Image.CalibrationIlluminant2",
	[0xc65c] = "Image.BestQualityScale",
	[0xc65d] = "Image.RawDataUniqueID",
	[0xc68b] = "Image.OriginalRawFileName",
	[0xc68c] = "Image.OriginalRawFileData",
	[0xc68d] = "Image.ActiveArea",
	[0xc68e] = "Image.MaskedAreas",
	[0xc68f] = "Image.AsShotICCProfile",
	[0xc690] = "Image.AsShotPreProfileMatrix",
	[0xc691] = "Image.CurrentICCProfile",
	[0xc692] = "Image.CurrentPreProfileMatrix",
	[0xc6bf] = "Image.ColorimetricReference",
	[0xc6f3] = "Image.CameraCalibrationSignature",
	[0xc6f4] = "Image.ProfileCalibrationSignature",
	[0xc6f5] = "Image.ExtraCameraProfiles",
	[0xc6f6] = "Image.AsShotProfileName",
	[0xc6f7] = "Image.NoiseReductionApplied",
	[0xc6f8] = "Image.ProfileName",
	[0xc6f9] = "Image.ProfileHueSatMapDims",
	[0xc6fa] = "Image.ProfileHueSatMapData1",
	[0xc6fb] = "Image.ProfileHueSatMapData2",
	[0xc6fc] = "Image.ProfileToneCurve",
	[0xc6fd] = "Image.ProfileEmbedPolicy",
	[0xc6fe] = "Image.ProfileCopyright",
	[0xc714] = "Image.ForwardMatrix1",
	[0xc715] = "Image.ForwardMatrix2",
	[0xc716] = "Image.PreviewApplicationName",
	[0xc717] = "Image.PreviewApplicationVersion",
	[0xc718] = "Image.PreviewSettingsName",
	[0xc719] = "Image.PreviewSettingsDigest",
	[0xc71a] = "Image.PreviewColorSpace",
	[0xc71b] = "Image.PreviewDateTime",
	[0xc71c] = "Image.RawImageDigest",
	[0xc71d] = "Image.OriginalRawFileDigest",
	[0xc71e] = "Image.SubTileBlockSize",
	[0xc71f] = "Image.RowInterleaveFactor",
	[0xc725] = "Image.ProfileLookTableDims",
	[0xc726] = "Image.ProfileLookTableData",
	[0xc740] = "Image.OpcodeList1",
	[0xc741] = "Image.OpcodeList2",
	[0xc74e] = "Image.OpcodeList3",
	[0xc761] = "Image.NoiseProfile",
	[0xc763] = "Image.TimeCodes",
	[0xc764] = "Image.FrameRate",
	[0xc772] = "Image.TStop",
	[0xc789] = "Image.ReelName",
	[0xc7a1] = "Image.CameraLabel",
	[0xc791] = "Image.OriginalDefaultFinalSize",
	[0xc792] = "Image.OriginalBestQualityFinalSize",
	[0xc793] = "Image.OriginalDefaultCropSize",
	[0xc7a3] = "Image.ProfileHueSatMapEncoding",
	[0xc7a4] = "Image.ProfileLookTableEncoding",
	[0xc7a5] = "Image.BaselineExposureOffset",
	[0xc7a6] = "Image.DefaultBlackRender",
	[0xc7a7] = "Image.NewRawImageDigest",
	[0xc7a8] = "Image.RawToPreviewGain",
	[0xc7b5] = "Image.DefaultUserCrop",
	[0xc7e9] = "Image.DepthFormat",
	[0xc7ea] = "Image.DepthNear",
	[0xc7eb] = "Image.DepthFar",
	[0xc7ec] = "Image.DepthUnits",
	[0xc7ed] = "Image.DepthMeasureType",
	[0xc7ee] = "Image.EnhanceParams",
	[0xcd2d] = "Image.ProfileGainTableMap",
	[0xcd2e] = "Image.SemanticName",
	[0xcd30] = "Image.SemanticInstanceID",
	[0xcd31] = "Image.CalibrationIlluminant3",
	[0xcd32] = "Image.CameraCalibration3",
	[0xcd33] = "Image.ColorMatrix3",
	[0xcd34] = "Image.ForwardMatrix3",
	[0xcd35] = "Image.IlluminantData1",
	[0xcd36] = "Image.IlluminantData2",
	[0xcd37] = "Image.IlluminantData3",
	[0xcd39] = "Image.ProfileHueSatMapData3",
	[0xcd3a] = "Image.ReductionMatrix3",
	[0x829a] = "Photo.ExposureTime",
	[0x829d] = "Photo.FNumber",
	[0x8822] = "Photo.ExposureProgram",
	[0x8824] = "Photo.SpectralSensitivity",
	[0x8827] = "Photo.ISOSpeedRatings",
	[0x8828] = "Photo.OECF",
	[0x8830] = "Photo.SensitivityType",
	[0x8831] = "Photo.StandardOutputSensitivity",
	[0x8832] = "Photo.RecommendedExposureIndex",
	[0x8833] = "Photo.ISOSpeed",
	[0x8834] = "Photo.ISOSpeedLatitudeyyy",
	[0x8835] = "Photo.ISOSpeedLatitudezzz",
	[0x9000] = "Photo.ExifVersion",
	[0x9003] = "Photo.DateTimeOriginal",
	[0x9004] = "Photo.DateTimeDigitized",
	[0x9010] = "Photo.OffsetTime",
	[0x9011] = "Photo.OffsetTimeOriginal",
	[0x9012] = "Photo.OffsetTimeDigitized",
	[0x9101] = "Photo.ComponentsConfiguration",
	[0x9102] = "Photo.CompressedBitsPerPixel",
	[0x9201] = "Photo.ShutterSpeedValue",
	[0x9202] = "Photo.ApertureValue",
	[0x9203] = "Photo.BrightnessValue",
	[0x9204] = "Photo.ExposureBiasValue",
	[0x9205] = "Photo.MaxApertureValue",
	[0x9206] = "Photo.SubjectDistance",
	[0x9207] = "Photo.MeteringMode",
	[0x9208] = "Photo.LightSource",
	[0x9209] = "Photo.Flash",
	[0x920a] = "Photo.FocalLength",
	[0x9214] = "Photo.SubjectArea",
	[0x927c] = "Photo.MakerNote",
	[0x9286] = "Photo.UserComment",
	[0x9290] = "Photo.SubSecTime",
	[0x9291] = "Photo.SubSecTimeOriginal",
	[0x9292] = "Photo.SubSecTimeDigitized",
	[0x9400] = "Photo.Temperature",
	[0x9401] = "Photo.Humidity",
	[0x9402] = "Photo.Pressure",
	[0x9403] = "Photo.WaterDepth",
	[0x9404] = "Photo.Acceleration",
	[0x9405] = "Photo.CameraElevationAngle",
	[0xa000] = "Photo.FlashpixVersion",
	[0xa001] = "Photo.ColorSpace",
	[0xa002] = "Photo.PixelXDimension",
	[0xa003] = "Photo.PixelYDimension",
	[0xa004] = "Photo.RelatedSoundFile",
	[0xa005] = "Photo.InteroperabilityTag",
	[0xa20b] = "Photo.FlashEnergy",
	[0xa20c] = "Photo.SpatialFrequencyResponse",
	[0xa20e] = "Photo.FocalPlaneXResolution",
	[0xa20f] = "Photo.FocalPlaneYResolution",
	[0xa210] = "Photo.FocalPlaneResolutionUnit",
	[0xa214] = "Photo.SubjectLocation",
	[0xa215] = "Photo.ExposureIndex",
	[0xa217] = "Photo.SensingMethod",
	[0xa300] = "Photo.FileSource",
	[0xa301] = "Photo.SceneType",
	[0xa302] = "Photo.CFAPattern",
	[0xa401] = "Photo.CustomRendered",
	[0xa402] = "Photo.ExposureMode",
	[0xa403] = "Photo.WhiteBalance",
	[0xa404] = "Photo.DigitalZoomRatio",
	[0xa405] = "Photo.FocalLengthIn35mmFilm",
	[0xa406] = "Photo.SceneCaptureType",
	[0xa407] = "Photo.GainControl",
	[0xa408] = "Photo.Contrast",
	[0xa409] = "Photo.Saturation",
	[0xa40a] = "Photo.Sharpness",
	[0xa40b] = "Photo.DeviceSettingDescription",
	[0xa40c] = "Photo.SubjectDistanceRange",
	[0xa420] = "Photo.ImageUniqueID",
	[0xa430] = "Photo.CameraOwnerName",
	[0xa431] = "Photo.BodySerialNumber",
	[0xa432] = "Photo.LensSpecification",
	[0xa433] = "Photo.LensMake",
	[0xa434] = "Photo.LensModel",
	[0xa435] = "Photo.LensSerialNumber",
	[0xa460] = "Photo.CompositeImage",
	[0xa461] = "Photo.SourceImageNumberOfCompositeImage",
	[0xa462] = "Photo.SourceExposureTimesOfCompositeImage",
	[0xa500] = "Photo.Gamma",
	[0x0001] = "Iop.InteroperabilityIndex",
	[0x0002] = "Iop.InteroperabilityVersion",
	[0x1000] = "Iop.RelatedImageFileFormat",
	[0x1001] = "Iop.RelatedImageWidth",
	[0x1002] = "Iop.RelatedImageLength",
	[0x0000] = "GPSInfo.GPSVersionID",
	[0x0001] = "GPSInfo.GPSLatitudeRef",
	[0x0002] = "GPSInfo.GPSLatitude",
	[0x0003] = "GPSInfo.GPSLongitudeRef",
	[0x0004] = "GPSInfo.GPSLongitude",
	[0x0005] = "GPSInfo.GPSAltitudeRef",
	[0x0006] = "GPSInfo.GPSAltitude",
	[0x0007] = "GPSInfo.GPSTimeStamp",
	[0x0008] = "GPSInfo.GPSSatellites",
	[0x0009] = "GPSInfo.GPSStatus",
	[0x000a] = "GPSInfo.GPSMeasureMode",
	[0x000b] = "GPSInfo.GPSDOP",
	[0x000c] = "GPSInfo.GPSSpeedRef",
	[0x000d] = "GPSInfo.GPSSpeed",
	[0x000e] = "GPSInfo.GPSTrackRef",
	[0x000f] = "GPSInfo.GPSTrack",
	[0x0010] = "GPSInfo.GPSImgDirectionRef",
	[0x0011] = "GPSInfo.GPSImgDirection",
	[0x0012] = "GPSInfo.GPSMapDatum",
	[0x0013] = "GPSInfo.GPSDestLatitudeRef",
	[0x0014] = "GPSInfo.GPSDestLatitude",
	[0x0015] = "GPSInfo.GPSDestLongitudeRef",
	[0x0016] = "GPSInfo.GPSDestLongitude",
	[0x0017] = "GPSInfo.GPSDestBearingRef",
	[0x0018] = "GPSInfo.GPSDestBearing",
	[0x0019] = "GPSInfo.GPSDestDistanceRef",
	[0x001a] = "GPSInfo.GPSDestDistance",
	[0x001b] = "GPSInfo.GPSProcessingMethod",
	[0x001c] = "GPSInfo.GPSAreaInformation",
	[0x001d] = "GPSInfo.GPSDateStamp",
	[0x001e] = "GPSInfo.GPSDifferential",
	[0x001f] = "GPSInfo.GPSHPositioningError",
} --}}}

local ifd_formats = {
	[1] =  "uint8_t",
	[2] =  "string",
	[3] =  "uint16_t",
	[4] =  "uint32_t",
	[5] =  "ufrac", --unsigned rational
	[6] =  "int8_t",
	[7] =  "unknown", --unknown
	[8] =  "int16_t",
	[9] =  "int32_t",
	[10] = "ifrac", --signed rational
	[11] = "float",
	[12] = "double",
}
local ifd_format_sizes = {
	[1] = 1,
	[2] = 1,
	[3] = 2,
	[4] = 4,
	[5] = 8,
	[6] = 1,
	[7] = 1,
	[8] = 2,
	[9] = 4,
	[10] = 8,
	[11] = 4,
	[12] = 8,
}

local inset
local function print_in(...)
	do return end
	local str = sfmt(...)
	printf("%s%s", inset or "", str)
end

local function read_ifd(self, offset)
	local base_ptr = self.base_ptr
	local exif_pos = self.exif_pos
	local eswap16 = self.eswap16
	local eswap32 = self.eswap32
	local bigendian = self.data_storage == "Motorola"

	inset = inset and inset .. "  > " or ""

	local pos = exif_pos + offset

	local num_ifd = eswap16(ffi.cast("uint16_t *", base_ptr + pos)[0])
	pos = pos + 2
	print_in("EXIF: IFD: %d entries, 1st position: 0x%x\n", num_ifd, pos)


	local ifd_entry_size = ffi.sizeof("struct ifd_entry")
	for i = 1, num_ifd do
		local entry = ffi.cast("struct ifd_entry *", base_ptr + pos)
		local tagdata
		do
			local tag = eswap16(entry.tag)
			local tag_str = ifd_tags[tag] or sfmt("0x%04x", tag)
			local format = eswap16(entry.format)
			local format_str = ifd_formats[format] or format
			local fsize = ifd_format_sizes[format]
			local nelm = eswap32(entry.number)
			local data_size = fsize * nelm
			local data_offset = eswap32(entry.data_off)
			--log.exif("raw data: 0x%08x, swapped: 0x%08x",
			--	entry.data_off, data_offset
			--)
			if bigendian and fsize == 2 then
				data_offset = band(rshift(data_offset, 16), 0xffff)
			end
			tagdata = data_offset
			--log.exif("offset: %08x -> %08x", entry.data_off, data_offset)

			local data_string = ""
			if (format_str == "string" or format_str == "unknown") and
				data_size <= 4
			then
				--printf("!! %s !!\n", tag_str)
				local sc = string.char
				data_string =
					sc(       band(data_offset, 0x000000ff)     )..
					sc(rshift(band(data_offset, 0x0000ff00),  8))..
					sc(rshift(band(data_offset, 0x00ff0000), 16))..
					sc(rshift(band(data_offset, 0xff000000), 24))
				if format_str == "unknown" then
					data_string = sfmt("\"%s\" 0x%x", data_string, data_offset)
				end
			else
				data_string = sfmt("0x%x,%d", data_offset, data_offset)
			end
			local bigstr
			if data_size > 4 then
				local data = ffi.cast(format_str,
					base_ptr + exif_pos + data_offset
				)
				--log.exif("offset at position 0x%x", exif_pos + data_offset)

				if format_str == "string" then
					bigstr = sfmt("[ %32s ]", ffi.string(data, nelm))
				elseif format_str == "ufrac" or format_str == "ifrac" then
					data_string = sfmt("[ %d / %d ] 0x%X",
						eswap32(data.numerator),
						eswap32(data.denominator),
						data_offset
					)
				end
			end
			print_in("EXIF: %-30s:%8s: %2d*%2d (%2d), %s%s\n", tag_str,
				format_str,
				fsize, nelm, data_size,
				data_string,
				data_size > 4 and " o" or ""
			)
			if bigstr then print_in("EXIF:     %s\n", bigstr) end
			if tag_str == "Image.ExifTag" or
				tag_str == "Image.GPSTag" or
				tag_str == "Photo.InteroperabilityTag" then
				read_ifd(self, data_offset)
			end


		end
		if eswap16(entry.tag) == 0x0112 then
			--{{{ Orientation Data
			--log.exif("grabbing orientation data")
			local rotate = 0
			local swap_wh = false
			local offx = false
			local offy = false
			if eswap16(entry.format) ~= 3 and
				eswap32(entry.number) ~= 1
			then
				return nil, "invalid orientation data"
			end
			local orient_num = tagdata
			--log.exif("Orientation: %d", orient_num)
			local degrees = 0
			--orient_num == 1, no change
			--orient_num == 9, undefined, no change
			if orient_num == 3 then
				--rotate 180 degrees
				degrees = 180
				offx = true
				offy = true
			elseif orient_num == 6 then
				--rotate 90 clockwise
				degrees = 90
				swap_wh = true
				offx = true
			elseif orient_num == 8 then
				--rotate 90 counter-clockwise
				degrees = 270
				swap_wh = true
				offy = true
			end
			rotate = degrees * math.pi / 180

			local u = self.user
			u.rotate, u.swap_wh, u.offx, u.offy =
				rotate, swap_wh, offx, offy
			--print("Orientation data:", u.rotate, u.swap_wh, u.offx, u.offy)

			--break
			--}}} Orentation Data
		end
		pos = pos + ifd_entry_size
	end
	inset = string.sub(inset, 1, #inset - 4)
	return pos
end

--I'm going to assume that LINK is being run on an Intel (little endian) system
local function orientation(base_ptr)
	local pos = 0
	base_ptr = ffi.cast("char *", base_ptr)
	--TODO: casing data to struct require the struct to not be padded
	--although, this struct should be properly aligned anyways
	do
		local soi = swap16(ffi.cast("uint16_t *", base_ptr)[0])
		if soi ~= 0xffd8 then
			return nil, "invalid JPEG data"
		end
		--don't increase pos, pad in marker/exif_header will cover this
		pos = pos + 2
	end
	while true do
		local marker = ffi.cast("struct marker_header *", base_ptr + pos)
		--log.exif("0x%x, %d bytes", swap16(marker.marker), swap16(marker.size))
		local mmarker = swap16(marker.marker)
		if mmarker == 0xffe1 then
			break
		elseif mmarker == 0xffda then
			--Start of Scan, probably no meta data
			return false, "no exif header found"
		else
			--non-exif header, skip
			pos = pos + 2 + swap16(marker.size)
		end
	end

	--log.exif("Exif header at pos: 0x%x", pos)
	pos = pos - 2 --remove 2 bytes to account for padding in exif_header struct
	local exif = ffi.cast("struct exif_header *", base_ptr + pos)

	--log.exif("sizeof exif_header %d", ffi.sizeof("struct exif_header"))
	pos = pos + ffi.sizeof("struct exif_header")

	--start of exif is 8 bytes before end of exif_header
	local exif_pos = pos - 8
	--log.exif("data read 0x%x", pos)


	local eswap16 = noswap
	local eswap32 = noswap

	if not (swap16(exif.marker) == 0xffe1 and
		ffi.string(exif.magic, 6) == "Exif\0\0")
	then
		return nil, "invalid exif data"
	end

	local data_storage = "Intel"
	if exif.endianess == 0x4d4d then
		data_storage = "Motorola"
		--"Motorola" Big-Endian EXIF data
		eswap16 = swap16
		eswap32 = swap32
	end

	if eswap16(exif.tag_mark) ~= 42 then
		return nil, "invalid tiff header"
	end

	--log.exif("Reading exif data, %d bytes, %s storage",
	--	swap16(exif.size),
	--	data_storage
	--)


	local exif_t = {
		base_ptr = base_ptr,
		exif_pos = exif_pos,
		eswap16 = eswap16,
		eswap32 = eswap32,
		data_storage = data_storage,
		user = {},
	}

	local next_ifd_offset = eswap32(exif.ifd_offset)
	while next_ifd_offset ~= 0 do
		--print(sfmt("next offset %d,0x%x", next_ifd_offset, next_ifd_offset))
		inset = false --for prettier printing
		pos = read_ifd(exif_t, next_ifd_offset)
		next_ifd_offset = eswap32(ffi.cast("uint32_t *", base_ptr + pos)[0])
	end

	local u = exif_t.user
	--print("Orientation data:", u.rotate, u.swap_wh, u.offx, u.offy)
	return u.rotate, u.swap_wh, u.offx, u.offy
end

return {orientation = orientation}
