local AssetBridge = {
    Name = "AssetBridge",
    Version = "0.3.0",
    Config = {
        Cache = true,
        MaxBytes = 52428800,
        GIFMinFrameDelay = 0.02
    },
    Image = {},
    GIF = {},
    Audio = {},
    Cache = {},
    Capabilities = {}
}

AssetBridge.Gif = AssetBridge.GIF

local assetBridgeMemoryCache = {}
local assetBridgeActiveResources = setmetatable({}, {__mode = "k"})
local assetBridgeSessionGeneration = 0
local assetBridgeCloseInProgress = false
local assetBridgeRequestFunction = request or http_request
local assetBridgeWriteFileFunction = writefile
local assetBridgeReadFileFunction = readfile
local assetBridgeIsFileFunction = isfile
local assetBridgeDeleteFileFunction = delfile
local assetBridgeMakeFolderFunction = makefolder
local assetBridgeIsFolderFunction = isfolder
local assetBridgeGetCustomAssetFunction = getcustomasset or getsynasset
local assetBridgeBufferLibrary = buffer
local assetBridgeSoundService = game:GetService("SoundService")
local assetBridgeInstanceNew = Instance.new

local assetBridgeImageExtensions = {
    png = true,
    jpg = true,
    jpeg = true,
    gif = true,
    bmp = true,
    webp = true,
    tif = true,
    tiff = true
}

local assetBridgeAudioExtensions = {
    mp3 = true,
    wav = true,
    ogg = true,
    oga = true,
    flac = true,
    m4a = true,
    aac = true
}

local assetBridgeMimeExtensions = {
    ["image/png"] = "png",
    ["image/jpeg"] = "jpg",
    ["image/gif"] = "gif",
    ["image/bmp"] = "bmp",
    ["image/webp"] = "webp",
    ["image/tiff"] = "tiff",
    ["audio/mpeg"] = "mp3",
    ["audio/mp3"] = "mp3",
    ["audio/wav"] = "wav",
    ["audio/x-wav"] = "wav",
    ["audio/ogg"] = "ogg",
    ["audio/flac"] = "flac",
    ["audio/x-flac"] = "flac",
    ["audio/mp4"] = "m4a",
    ["audio/aac"] = "aac"
}

local function assetBridgeSafeGetGlobal(assetBridgeGlobalName)
    local assetBridgeGlobalValue = nil

    pcall(function()
        assetBridgeGlobalValue = getgenv()[assetBridgeGlobalName]
    end)

    if assetBridgeGlobalValue == nil then
        pcall(function()
            assetBridgeGlobalValue = _G[assetBridgeGlobalName]
        end)
    end

    return assetBridgeGlobalValue
end

local function assetBridgeRefreshCapabilities()
    local assetBridgeSynTable = assetBridgeSafeGetGlobal("syn")
    local assetBridgeHttpTable = assetBridgeSafeGetGlobal("http")

    assetBridgeRequestFunction = assetBridgeSafeGetGlobal("request") or assetBridgeSafeGetGlobal("http_request")

    if type(assetBridgeRequestFunction) ~= "function" and type(assetBridgeSynTable) == "table" then
        assetBridgeRequestFunction = assetBridgeSynTable.request
    end

    if type(assetBridgeRequestFunction) ~= "function" and type(assetBridgeHttpTable) == "table" then
        assetBridgeRequestFunction = assetBridgeHttpTable.request
    end

    assetBridgeWriteFileFunction = assetBridgeSafeGetGlobal("writefile") or assetBridgeWriteFileFunction
    assetBridgeReadFileFunction = assetBridgeSafeGetGlobal("readfile") or assetBridgeReadFileFunction
    assetBridgeIsFileFunction = assetBridgeSafeGetGlobal("isfile") or assetBridgeIsFileFunction
    assetBridgeDeleteFileFunction = assetBridgeSafeGetGlobal("delfile") or assetBridgeDeleteFileFunction
    assetBridgeMakeFolderFunction = assetBridgeSafeGetGlobal("makefolder") or assetBridgeMakeFolderFunction
    assetBridgeIsFolderFunction = assetBridgeSafeGetGlobal("isfolder") or assetBridgeIsFolderFunction
    assetBridgeGetCustomAssetFunction = assetBridgeSafeGetGlobal("getcustomasset") or assetBridgeSafeGetGlobal("getsynasset") or assetBridgeGetCustomAssetFunction

    AssetBridge.Capabilities = {
        Request = type(assetBridgeRequestFunction) == "function",
        GameHttpGet = type(game.HttpGet) == "function",
        WriteFile = type(assetBridgeWriteFileFunction) == "function",
        ReadFile = type(assetBridgeReadFileFunction) == "function",
        IsFile = type(assetBridgeIsFileFunction) == "function",
        DeleteFile = type(assetBridgeDeleteFileFunction) == "function",
        GetCustomAsset = type(assetBridgeGetCustomAssetFunction) == "function"
    }

    return AssetBridge.Capabilities
end

local function assetBridgeNormalizeUrl(assetBridgeUrl)
    if type(assetBridgeUrl) ~= "string" or assetBridgeUrl == "" then
        return nil, "URL must be a non-empty string."
    end

    if not string.match(assetBridgeUrl, "^https?://") then
        return nil, "Only HTTP and HTTPS URLs are supported."
    end

    local assetBridgeGithubOwner, assetBridgeGithubRepository, assetBridgeGithubBranch, assetBridgeGithubPath = string.match(
        assetBridgeUrl,
        "^https?://github%.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)$"
    )

    if assetBridgeGithubOwner then
        assetBridgeUrl = "https://raw.githubusercontent.com/" .. assetBridgeGithubOwner .. "/" .. assetBridgeGithubRepository .. "/" .. assetBridgeGithubBranch .. "/" .. assetBridgeGithubPath
    end

    return assetBridgeUrl
end

local function assetBridgeHashString(assetBridgeValue)
    local assetBridgeHash = 2166136261

    for assetBridgeIndex = 1, #assetBridgeValue do
        assetBridgeHash = (assetBridgeHash * 31 + string.byte(assetBridgeValue, assetBridgeIndex)) % 4294967296
    end

    return string.format("%08x", assetBridgeHash)
end

local function assetBridgeGetUrlExtension(assetBridgeUrl)
    local assetBridgeCleanUrl = string.match(assetBridgeUrl, "^[^?#]+") or assetBridgeUrl
    local assetBridgeExtension = string.match(assetBridgeCleanUrl, "%.([%w]+)$")

    if assetBridgeExtension then
        return string.lower(assetBridgeExtension)
    end

    return nil
end

local function assetBridgeGetHeader(assetBridgeHeaders, assetBridgeHeaderName)
    if type(assetBridgeHeaders) ~= "table" then
        return nil
    end

    local assetBridgeWantedHeader = string.lower(assetBridgeHeaderName)

    for assetBridgeName, assetBridgeValue in pairs(assetBridgeHeaders) do
        if string.lower(tostring(assetBridgeName)) == assetBridgeWantedHeader then
            return tostring(assetBridgeValue)
        end
    end

    return nil
end

local function assetBridgeDetectExtension(assetBridgeBytes, assetBridgeContentType, assetBridgeUrl)
    local assetBridgeMimeType = assetBridgeContentType and string.match(string.lower(assetBridgeContentType), "^[^;]+")

    if assetBridgeMimeType == "text/html" or assetBridgeMimeType == "application/xhtml+xml" then
        return nil
    end

    local assetBridgeLeadingBytes = string.lower(string.sub(assetBridgeBytes, 1, 256))
    if string.find(assetBridgeLeadingBytes, "<!doctype html", 1, true) or string.find(assetBridgeLeadingBytes, "<html", 1, true) then
        return nil
    end

    if string.sub(assetBridgeBytes, 1, 8) == "\137PNG\r\n\26\n" then
        return "png"
    end

    if string.sub(assetBridgeBytes, 1, 3) == "\255\216\255" then
        return "jpg"
    end

    local assetBridgeGifHeader = string.sub(assetBridgeBytes, 1, 6)
    if assetBridgeGifHeader == "GIF87a" or assetBridgeGifHeader == "GIF89a" then
        return "gif"
    end

    if string.sub(assetBridgeBytes, 1, 2) == "BM" then
        return "bmp"
    end

    if string.sub(assetBridgeBytes, 1, 4) == "RIFF" and string.sub(assetBridgeBytes, 9, 12) == "WEBP" then
        return "webp"
    end

    if string.sub(assetBridgeBytes, 1, 4) == "RIFF" and string.sub(assetBridgeBytes, 9, 12) == "WAVE" then
        return "wav"
    end

    if string.sub(assetBridgeBytes, 1, 4) == "OggS" then
        return "ogg"
    end

    if string.sub(assetBridgeBytes, 1, 4) == "fLaC" then
        return "flac"
    end

    if string.sub(assetBridgeBytes, 1, 3) == "ID3" then
        return "mp3"
    end

    local assetBridgeFirstByte, assetBridgeSecondByte = string.byte(assetBridgeBytes, 1, 2)
    if assetBridgeFirstByte == 255 and assetBridgeSecondByte and assetBridgeSecondByte >= 224 then
        return "mp3"
    end

    local assetBridgeMimeExtension = assetBridgeMimeType and assetBridgeMimeExtensions[assetBridgeMimeType]
    if assetBridgeMimeExtension then
        return assetBridgeMimeExtension
    end

    return assetBridgeGetUrlExtension(assetBridgeUrl)
end

local function assetBridgePerformHttpRequest(assetBridgeUrl, assetBridgeOptions)
    assetBridgeOptions = assetBridgeOptions or {}

    if type(assetBridgeRequestFunction) == "function" then
        local assetBridgeRequestArguments = {
            Url = assetBridgeUrl,
            Method = "GET",
            Headers = assetBridgeOptions.Headers or {}
        }

        if assetBridgeOptions.Timeout then
            assetBridgeRequestArguments.Timeout = assetBridgeOptions.Timeout
        end

        local assetBridgeRequestSuccess, assetBridgeHttpResponse = pcall(assetBridgeRequestFunction, assetBridgeRequestArguments)

        if assetBridgeRequestSuccess and type(assetBridgeHttpResponse) == "table" then
            local assetBridgeResponseBody = assetBridgeHttpResponse.Body or assetBridgeHttpResponse.body
            local assetBridgeStatusCode = assetBridgeHttpResponse.StatusCode or assetBridgeHttpResponse.Status or assetBridgeHttpResponse.status_code or assetBridgeHttpResponse.status
            local assetBridgeResponseHeaders = assetBridgeHttpResponse.Headers or assetBridgeHttpResponse.headers or {}

            if type(assetBridgeResponseBody) == "string" then
                if assetBridgeStatusCode and (tonumber(assetBridgeStatusCode) or 0) >= 400 then
                    return nil, "HTTP request failed with status " .. tostring(assetBridgeStatusCode) .. "."
                end

                return assetBridgeResponseBody, assetBridgeResponseHeaders, tonumber(assetBridgeStatusCode)
            end

            return nil, "The executor HTTP response did not contain a string Body."
        end

        if assetBridgeRequestSuccess and type(assetBridgeHttpResponse) == "string" then
            return assetBridgeHttpResponse, {}, 200
        end
    end

    local assetBridgeHttpGetSuccess, assetBridgeHttpBody = pcall(function()
        return game:HttpGet(assetBridgeUrl)
    end)

    if assetBridgeHttpGetSuccess and type(assetBridgeHttpBody) == "string" then
        return assetBridgeHttpBody, {}, 200
    end

    if type(assetBridgeHttpBody) == "string" then
        return nil, assetBridgeHttpBody
    end

    return nil, "No compatible HTTP request function succeeded."
end

local assetBridgeCacheRoot = "abysall/AssetBridge"
local assetBridgeTrackedFiles = {}
local assetBridgeCacheDirectories = {
    GIF = assetBridgeCacheRoot .. "/gif",
    Audio = assetBridgeCacheRoot .. "/audio",
    Image = assetBridgeCacheRoot .. "/png",
    YouTube = assetBridgeCacheRoot .. "/youtube"
}

AssetBridge.Cache.Directories = {
    Root = assetBridgeCacheRoot,
    GIF = assetBridgeCacheDirectories.GIF,
    Audio = assetBridgeCacheDirectories.Audio,
    PNG = assetBridgeCacheDirectories.Image,
    YouTube = assetBridgeCacheDirectories.YouTube
}

local function assetBridgeEnsureFolder(assetBridgeFolderPath)
    if type(assetBridgeMakeFolderFunction) ~= "function" then
        return false, "This executor does not expose makefolder()."
    end

    local currentFolderPath = ""
    for folderSegment in string.gmatch(assetBridgeFolderPath, "[^/]+") do
        currentFolderPath = currentFolderPath == "" and folderSegment or (currentFolderPath .. "/" .. folderSegment)

        local folderExists = false
        if type(assetBridgeIsFolderFunction) == "function" then
            local folderCheckSuccess, folderCheckResult = pcall(assetBridgeIsFolderFunction, currentFolderPath)
            folderExists = folderCheckSuccess and folderCheckResult == true
        end

        if not folderExists then
            local folderCreateSuccess, folderCreateError = pcall(assetBridgeMakeFolderFunction, currentFolderPath)
            if not folderCreateSuccess and type(assetBridgeIsFolderFunction) == "function" then
                local recheckSuccess, recheckExists = pcall(assetBridgeIsFolderFunction, currentFolderPath)
                if not (recheckSuccess and recheckExists == true) then
                    return false, "Could not create cache folder '" .. currentFolderPath .. "': " .. tostring(folderCreateError)
                end
            end
        end
    end

    return true
end

local function assetBridgeGetCacheDirectory(assetBridgeExpectedType, assetBridgeExtension)
    if assetBridgeExpectedType == "Audio" then
        return assetBridgeCacheDirectories.Audio
    end
    if assetBridgeExpectedType == "GIF" or assetBridgeExtension == "gif" then
        return assetBridgeCacheDirectories.GIF
    end
    return assetBridgeCacheDirectories.Image
end

local function assetBridgeBuildCachePath(assetBridgeUrl, assetBridgeExtension, assetBridgeExpectedType)
    local cacheDirectory = assetBridgeGetCacheDirectory(assetBridgeExpectedType, assetBridgeExtension)
    return cacheDirectory .. "/" .. assetBridgeHashString(assetBridgeUrl) .. "." .. assetBridgeExtension
end

for _, assetBridgeDirectoryPath in pairs(assetBridgeCacheDirectories) do
    assetBridgeEnsureFolder(assetBridgeDirectoryPath)
end

local function assetBridgeFileExists(assetBridgePath)
    if type(assetBridgeIsFileFunction) ~= "function" then
        return false
    end

    local assetBridgeSuccess, assetBridgeExists = pcall(assetBridgeIsFileFunction, assetBridgePath)
    return assetBridgeSuccess and assetBridgeExists == true
end

local function assetBridgeGetCachedFile(assetBridgeUrl, assetBridgeExpectedType, assetBridgeOptions)
    local assetBridgeKnownExtension = assetBridgeGetUrlExtension(assetBridgeUrl)

    if not assetBridgeKnownExtension then
        return nil
    end

    local assetBridgeIsAllowedExtension = assetBridgeExpectedType == "Image" and assetBridgeImageExtensions[assetBridgeKnownExtension]
        or assetBridgeExpectedType == "Audio" and assetBridgeAudioExtensions[assetBridgeKnownExtension]

    if not assetBridgeIsAllowedExtension then
        return nil
    end

    local assetBridgeCachePath = assetBridgeBuildCachePath(assetBridgeUrl, assetBridgeKnownExtension, assetBridgeExpectedType)

    if not assetBridgeFileExists(assetBridgeCachePath) then
        return nil
    end

    local assetBridgeCachedBytes = nil
    if type(assetBridgeReadFileFunction) == "function" then
        local assetBridgeReadSuccess, assetBridgeReadResult = pcall(assetBridgeReadFileFunction, assetBridgeCachePath)
        if assetBridgeReadSuccess and type(assetBridgeReadResult) == "string" then
            assetBridgeCachedBytes = assetBridgeReadResult
        end
    end

    return {
        Url = assetBridgeUrl,
        FilePath = assetBridgeCachePath,
        Bytes = assetBridgeCachedBytes,
        Size = assetBridgeCachedBytes and #assetBridgeCachedBytes or nil,
        Extension = assetBridgeKnownExtension,
        ContentType = nil,
        Cached = true
    }
end

local function assetBridgeDownload(assetBridgeUrl, assetBridgeExpectedType, assetBridgeOptions)
    assetBridgeOptions = assetBridgeOptions or {}
    if assetBridgeCloseInProgress then
        return nil, "AssetBridge is closing."
    end
    local requestSessionGeneration = assetBridgeSessionGeneration

    local assetBridgeNormalizedUrl, assetBridgeNormalizeError = assetBridgeNormalizeUrl(assetBridgeUrl)
    if not assetBridgeNormalizedUrl then
        return nil, assetBridgeNormalizeError
    end

    local assetBridgeCacheKey = assetBridgeExpectedType .. ":" .. assetBridgeNormalizedUrl
    local assetBridgeUseCache = assetBridgeOptions.Cache
    if assetBridgeUseCache == nil then
        assetBridgeUseCache = AssetBridge.Config.Cache
    end

    if assetBridgeUseCache and not assetBridgeOptions.Refresh then
        local assetBridgeMemoryCachedAsset = assetBridgeMemoryCache[assetBridgeCacheKey]
        if assetBridgeMemoryCachedAsset then
            return assetBridgeMemoryCachedAsset
        end

        local assetBridgePersistentCachedAsset = assetBridgeGetCachedFile(assetBridgeNormalizedUrl, assetBridgeExpectedType, assetBridgeOptions)
        if assetBridgePersistentCachedAsset then
            assetBridgeMemoryCache[assetBridgeCacheKey] = assetBridgePersistentCachedAsset
            return assetBridgePersistentCachedAsset
        end
    end

    if type(assetBridgeWriteFileFunction) ~= "function" then
        return nil, "This executor does not expose writefile()."
    end

    local assetBridgeDownloadedBytes, assetBridgeResponseHeaders, assetBridgeStatusCode = assetBridgePerformHttpRequest(assetBridgeNormalizedUrl, assetBridgeOptions)
    if type(assetBridgeDownloadedBytes) ~= "string" then
        return nil, assetBridgeResponseHeaders or "Download failed."
    end
    if requestSessionGeneration ~= assetBridgeSessionGeneration or assetBridgeCloseInProgress then
        return nil, "AssetBridge was closed during the download."
    end

    local assetBridgeMaximumBytes = tonumber(assetBridgeOptions.MaxBytes) or tonumber(AssetBridge.Config.MaxBytes) or 52428800
    if #assetBridgeDownloadedBytes > assetBridgeMaximumBytes then
        return nil, "The downloaded file exceeds the configured MaxBytes limit."
    end

    local assetBridgeContentType = assetBridgeGetHeader(assetBridgeResponseHeaders, "content-type")
    local assetBridgeDetectedExtension = assetBridgeDetectExtension(assetBridgeDownloadedBytes, assetBridgeContentType, assetBridgeNormalizedUrl)

    if not assetBridgeDetectedExtension then
        return nil, "Could not identify the downloaded file format."
    end

    local assetBridgeExtensionAllowed = assetBridgeExpectedType == "Image" and assetBridgeImageExtensions[assetBridgeDetectedExtension]
        or assetBridgeExpectedType == "Audio" and assetBridgeAudioExtensions[assetBridgeDetectedExtension]

    if not assetBridgeExtensionAllowed then
        return nil, "The URL did not return a supported " .. string.lower(assetBridgeExpectedType) .. " format. Detected: " .. assetBridgeDetectedExtension
    end

    local assetBridgeCachePath = assetBridgeBuildCachePath(assetBridgeNormalizedUrl, assetBridgeDetectedExtension, assetBridgeExpectedType)
    local cacheFolderSuccess, cacheFolderError = assetBridgeEnsureFolder(assetBridgeGetCacheDirectory(assetBridgeExpectedType, assetBridgeDetectedExtension))
    if not cacheFolderSuccess then
        return nil, cacheFolderError
    end

    local assetBridgeWriteSuccess, assetBridgeWriteError = pcall(assetBridgeWriteFileFunction, assetBridgeCachePath, assetBridgeDownloadedBytes)

    if not assetBridgeWriteSuccess then
        return nil, "Could not write the downloaded file: " .. tostring(assetBridgeWriteError)
    end
    assetBridgeTrackedFiles[assetBridgeCachePath] = true

    local assetBridgeAssetData = {
        Url = assetBridgeNormalizedUrl,
        FilePath = assetBridgeCachePath,
        Bytes = assetBridgeDownloadedBytes,
        Size = #assetBridgeDownloadedBytes,
        Extension = assetBridgeDetectedExtension,
        ContentType = assetBridgeContentType,
        StatusCode = assetBridgeStatusCode,
        Cached = false
    }

    if assetBridgeUseCache then
        assetBridgeMemoryCache[assetBridgeCacheKey] = assetBridgeAssetData
    end

    return assetBridgeAssetData
end

local function assetBridgeGetCustomAssetId(assetBridgeFilePath)
    if type(assetBridgeGetCustomAssetFunction) ~= "function" then
        return nil, "This executor does not expose getcustomasset() or getsynasset()."
    end

    local assetBridgeAssetSuccess, assetBridgeAssetId = pcall(assetBridgeGetCustomAssetFunction, assetBridgeFilePath)

    if not assetBridgeAssetSuccess or type(assetBridgeAssetId) ~= "string" then
        return nil, tostring(assetBridgeAssetId or "Could not create a local asset reference.")
    end

    return assetBridgeAssetId
end

local function assetBridgeCreateImageAsset(downloadedAsset)
    local imageAssetId, assetIdError = assetBridgeGetCustomAssetId(downloadedAsset.FilePath)

    if not imageAssetId then
        return nil, assetIdError or "Could not create a local image asset reference."
    end

    local imageAsset = {
        Url = downloadedAsset.Url,
        ImageId = imageAssetId,
        ImageID = imageAssetId,
        Imageid = imageAssetId,
        FilePath = downloadedAsset.FilePath,
        Format = downloadedAsset.Extension,
        Size = downloadedAsset.Size,
        Cached = downloadedAsset.Cached,
        Method = "Native"
    }

    function imageAsset:Apply(targetImageObject)
        if typeof(targetImageObject) ~= "Instance" then
            return false, "Apply() requires a Roblox Instance."
        end

        if targetImageObject:IsA("Decal") or targetImageObject:IsA("Texture") then
            targetImageObject.Texture = self.ImageId
            return true
        end

        if targetImageObject:IsA("ImageLabel") or targetImageObject:IsA("ImageButton") then
            targetImageObject.Image = self.ImageId
            return true
        end

        return false, "Images can be applied to Decal, Texture, ImageLabel or ImageButton instances."
    end

    function imageAsset:CreateLabel(parentInstance, labelProperties)
        if typeof(parentInstance) ~= "Instance" then
            return nil, "CreateLabel() requires a parent Instance."
        end

        labelProperties = labelProperties or {}
        local imageLabel = assetBridgeInstanceNew("ImageLabel")
        imageLabel.Name = labelProperties.Name or "AssetBridgeImage"
        imageLabel.BackgroundTransparency = labelProperties.BackgroundTransparency == nil and 1 or labelProperties.BackgroundTransparency
        imageLabel.Size = labelProperties.Size or UDim2.new(1, 0, 1, 0)
        imageLabel.Position = labelProperties.Position or UDim2.new(0, 0, 0, 0)
        imageLabel.ScaleType = labelProperties.ScaleType or Enum.ScaleType.Fit

        for propertyName, propertyValue in pairs(labelProperties) do
            if propertyName ~= "Name" and propertyName ~= "Parent" then
                local propertySuccess, propertyError = pcall(function()
                    imageLabel[propertyName] = propertyValue
                end)

                if not propertySuccess then
                    imageLabel:Destroy()
                    return nil, "Invalid ImageLabel property " .. tostring(propertyName) .. ": " .. tostring(propertyError)
                end
            end
        end

        imageLabel.Parent = parentInstance
        imageLabel.Image = self.ImageId
        return imageLabel
    end

    return imageAsset
end

function AssetBridge.Image.Fetch(imageUrl, imageOptions)
    imageOptions = imageOptions or {}
    local downloadedImage, downloadError = assetBridgeDownload(imageUrl, "Image", imageOptions)

    if not downloadedImage then
        return nil, downloadError
    end

    if downloadedImage.Extension == "gif" then
        return nil, "Animated GIFs must be loaded with AssetBridge.GIF.Fetch()."
    end

    return assetBridgeCreateImageAsset(downloadedImage)
end

local function assetBridgeGifReadUInt16(gifBytes, gifPosition)
    local gifLowByte, gifHighByte = string.byte(gifBytes, gifPosition, gifPosition + 1)
    if not gifHighByte then
        return nil, "Unexpected end of GIF while reading a 16-bit value."
    end
    return gifLowByte + gifHighByte * 256
end

local function assetBridgeGifReadColorTable(gifBytes, gifPosition, gifColorCount)
    local gifColorTable = {}

    for gifColorIndex = 0, gifColorCount - 1 do
        local gifRed, gifGreen, gifBlue = string.byte(gifBytes, gifPosition, gifPosition + 2)
        if not gifBlue then
            return nil, nil, "Unexpected end of GIF color table."
        end
        gifColorTable[gifColorIndex] = string.char(gifRed, gifGreen, gifBlue, 255)
        gifPosition = gifPosition + 3
    end

    return gifColorTable, gifPosition
end

local function assetBridgeGifReadSubBlocks(gifBytes, gifPosition)
    local gifSubBlockParts = {}

    while true do
        local gifBlockLength = string.byte(gifBytes, gifPosition)
        if not gifBlockLength then
            return nil, nil, "Unexpected end of GIF data sub-blocks."
        end

        gifPosition = gifPosition + 1
        if gifBlockLength == 0 then
            break
        end

        local gifBlockEnd = gifPosition + gifBlockLength - 1
        if gifBlockEnd > #gifBytes then
            return nil, nil, "GIF data sub-block exceeds the downloaded file."
        end

        gifSubBlockParts[#gifSubBlockParts + 1] = string.sub(gifBytes, gifPosition, gifBlockEnd)
        gifPosition = gifBlockEnd + 1
    end

    return table.concat(gifSubBlockParts), gifPosition
end

local function assetBridgeGifDecodeLZW(gifCompressedBytes, gifMinimumCodeSize, gifExpectedPixelCount, gifYieldEveryCodes)
    if gifMinimumCodeSize < 2 or gifMinimumCodeSize > 8 then
        return nil, "GIF uses an unsupported LZW minimum code size."
    end

    local gifClearCode = 2 ^ gifMinimumCodeSize
    local gifEndCode = gifClearCode + 1
    local gifCodeSize = gifMinimumCodeSize + 1
    local gifNextCode = gifEndCode + 1
    local gifPrefix = {}
    local gifSuffix = {}
    local gifExpansionStack = {}
    local gifBitPosition = 0
    local gifBytePosition = 1
    local gifBitBuffer = 0
    local gifBitCount = 0
    local gifOutputParts = nil
    local gifOutputChunk = nil
    local gifOutputChunkCount = 0
    local gifOutputLength = 0
    local gifOutputBuffer = nil

    if assetBridgeBufferLibrary
        and type(assetBridgeBufferLibrary.create) == "function"
        and type(assetBridgeBufferLibrary.writeu8) == "function"
        and type(assetBridgeBufferLibrary.tostring) == "function" then
        local outputBufferSuccess, outputBuffer = pcall(assetBridgeBufferLibrary.create, gifExpectedPixelCount)
        if outputBufferSuccess and outputBuffer then
            gifOutputBuffer = outputBuffer
        end
    end

    if not gifOutputBuffer then
        gifOutputParts = {}
        gifOutputChunk = table.create and table.create(1024) or {}
    end
    local gifPreviousCode = nil
    local gifProcessedCodeCount = 0
    local gifUnpack = table.unpack or unpack

    local function assetBridgeGifReadCode(codeWidth)
        while gifBitCount < codeWidth do
            local nextByte = string.byte(gifCompressedBytes, gifBytePosition)
            if not nextByte then
                return nil
            end
            if bit32 then
                gifBitBuffer = bit32.bor(gifBitBuffer, bit32.lshift(nextByte, gifBitCount))
            else
                gifBitBuffer = gifBitBuffer + nextByte * (2 ^ gifBitCount)
            end
            gifBitCount = gifBitCount + 8
            gifBytePosition = gifBytePosition + 1
        end

        local codeModulus = 2 ^ codeWidth
        local decodedCode
        if bit32 then
            decodedCode = bit32.band(gifBitBuffer, codeModulus - 1)
            gifBitBuffer = bit32.rshift(gifBitBuffer, codeWidth)
        else
            decodedCode = gifBitBuffer % codeModulus
            gifBitBuffer = math.floor(gifBitBuffer / codeModulus)
        end
        gifBitCount = gifBitCount - codeWidth
        return decodedCode
    end

    local function assetBridgeGifFlushOutputChunk()
        if gifOutputChunkCount > 0 then
            gifOutputParts[#gifOutputParts + 1] = string.char(gifUnpack(gifOutputChunk, 1, gifOutputChunkCount))
            if table.clear then
                table.clear(gifOutputChunk)
            else
                gifOutputChunk = {}
            end
            gifOutputChunkCount = 0
        end
    end

    local function assetBridgeGifAppendOutputByte(outputByte)
        gifOutputLength = gifOutputLength + 1
        if gifOutputLength > gifExpectedPixelCount then
            return false, "GIF frame decoded to more pixels than its dimensions allow."
        end

        if gifOutputBuffer then
            assetBridgeBufferLibrary.writeu8(gifOutputBuffer, gifOutputLength - 1, outputByte)
        else
            gifOutputChunkCount = gifOutputChunkCount + 1
            gifOutputChunk[gifOutputChunkCount] = outputByte
            if gifOutputChunkCount >= 1024 then
                assetBridgeGifFlushOutputChunk()
            end
        end
        return true
    end

    local function assetBridgeGifResetDictionary()
        table.clear(gifPrefix)
        table.clear(gifSuffix)
        for literalIndex = 0, gifClearCode - 1 do
            gifSuffix[literalIndex] = literalIndex
        end
        gifCodeSize = gifMinimumCodeSize + 1
        gifNextCode = gifEndCode + 1
        gifPreviousCode = nil
    end

    local function assetBridgeGifExpandCode(expansionCode)
        local stackCount = 0
        local currentCode = expansionCode

        while currentCode >= gifClearCode do
            if currentCode >= gifNextCode or gifSuffix[currentCode] == nil then
                return nil, "Invalid GIF LZW dictionary reference."
            end
            stackCount = stackCount + 1
            gifExpansionStack[stackCount] = gifSuffix[currentCode]
            currentCode = gifPrefix[currentCode]
            if currentCode == nil then
                return nil, "Invalid GIF LZW dictionary chain."
            end
        end

        stackCount = stackCount + 1
        gifExpansionStack[stackCount] = gifSuffix[currentCode]
        return stackCount, gifExpansionStack[stackCount]
    end

    assetBridgeGifResetDictionary()

    while true do
        local currentCode = assetBridgeGifReadCode(gifCodeSize)
        gifProcessedCodeCount = gifProcessedCodeCount + 1
        if gifYieldEveryCodes and gifYieldEveryCodes > 0 and gifProcessedCodeCount % gifYieldEveryCodes == 0 then
            task.wait()
        end
        if currentCode == nil then
            break
        end

        if currentCode == gifClearCode then
            assetBridgeGifResetDictionary()
        elseif currentCode == gifEndCode then
            break
        else
            local currentStackCount
            local currentFirstByte
            local isNextCodeCase = currentCode == gifNextCode and gifPreviousCode ~= nil

            if isNextCodeCase then
                currentStackCount, currentFirstByte = assetBridgeGifExpandCode(gifPreviousCode)
            elseif currentCode < gifNextCode then
                currentStackCount, currentFirstByte = assetBridgeGifExpandCode(currentCode)
            else
                return nil, "Invalid GIF LZW code encountered."
            end

            if not currentStackCount then
                return nil, currentFirstByte
            end

            for stackIndex = currentStackCount, 1, -1 do
                local appendSuccess, appendError = assetBridgeGifAppendOutputByte(gifExpansionStack[stackIndex])
                if not appendSuccess then
                    return nil, appendError
                end
            end

            if isNextCodeCase then
                local appendSuccess, appendError = assetBridgeGifAppendOutputByte(currentFirstByte)
                if not appendSuccess then
                    return nil, appendError
                end
            end

            if gifPreviousCode ~= nil and gifNextCode < 4096 then
                gifPrefix[gifNextCode] = gifPreviousCode
                gifSuffix[gifNextCode] = currentFirstByte
                gifNextCode = gifNextCode + 1

                if gifNextCode >= 2 ^ gifCodeSize and gifCodeSize < 12 then
                    gifCodeSize = gifCodeSize + 1
                end
            end

            gifPreviousCode = currentCode
        end
    end

    local decodedPixels
    if gifOutputBuffer then
        decodedPixels = assetBridgeBufferLibrary.tostring(gifOutputBuffer)
    else
        assetBridgeGifFlushOutputChunk()
        decodedPixels = table.concat(gifOutputParts)
    end
    if #decodedPixels < gifExpectedPixelCount then
        return nil, "GIF frame did not contain enough decoded pixels."
    end

    return decodedPixels
end

local assetBridgeGifPackedPixelCache = {}

local function assetBridgeGifGetPackedPixel(pixelBytes)
    local packedPixel = assetBridgeGifPackedPixelCache[pixelBytes]
    if packedPixel ~= nil then
        return packedPixel
    end

    local redValue, greenValue, blueValue, alphaValue = string.byte(pixelBytes, 1, 4)
    packedPixel = redValue + greenValue * 256 + blueValue * 65536 + alphaValue * 16777216
    assetBridgeGifPackedPixelCache[pixelBytes] = packedPixel
    return packedPixel
end

local function assetBridgeGifGetCanvasBuffer(gifCanvasRows)
    if type(gifCanvasRows) == "table" then
        return rawget(gifCanvasRows, "_buffer")
    end
    return nil
end

local function assetBridgeGifCloneCanvas(gifCanvasRows, gifHeight)
    local originalBuffer = assetBridgeGifGetCanvasBuffer(gifCanvasRows)
    if originalBuffer
        and assetBridgeBufferLibrary
        and type(assetBridgeBufferLibrary.len) == "function"
        and type(assetBridgeBufferLibrary.copy) == "function" then
        local canvasBufferSize = assetBridgeBufferLibrary.len(originalBuffer)
        local clonedBuffer = assetBridgeBufferLibrary.create(canvasBufferSize)
        assetBridgeBufferLibrary.copy(clonedBuffer, 0, originalBuffer, 0, canvasBufferSize)
        return {
            _buffer = clonedBuffer,
            _width = gifCanvasRows._width,
            _height = gifCanvasRows._height
        }
    end

    local clonedCanvasRows = {}
    for gifRowIndex = 1, gifHeight do
        local originalRow = gifCanvasRows[gifRowIndex]
        local clonedRow = {}
        for gifColumnIndex = 1, #originalRow do
            clonedRow[gifColumnIndex] = originalRow[gifColumnIndex]
        end
        clonedCanvasRows[gifRowIndex] = clonedRow
    end
    return clonedCanvasRows
end

local function assetBridgeGifCreateCanvas(gifWidth, gifHeight, gifFillPixel)
    if assetBridgeBufferLibrary
        and type(assetBridgeBufferLibrary.create) == "function"
        and type(assetBridgeBufferLibrary.writeu32) == "function"
        and type(assetBridgeBufferLibrary.readu32) == "function"
        and type(assetBridgeBufferLibrary.readstring) == "function"
        and type(assetBridgeBufferLibrary.len) == "function"
        and type(assetBridgeBufferLibrary.copy) == "function" then
        local canvasByteCount = gifWidth * gifHeight * 4
        local createSuccess, canvasBuffer = pcall(assetBridgeBufferLibrary.create, canvasByteCount)
        if createSuccess and canvasBuffer then
            local packedFillPixel = assetBridgeGifGetPackedPixel(gifFillPixel)
            if packedFillPixel ~= 0 then
                for pixelIndex = 0, gifWidth * gifHeight - 1 do
                    assetBridgeBufferLibrary.writeu32(canvasBuffer, pixelIndex * 4, packedFillPixel)
                end
            end
            return {
                _buffer = canvasBuffer,
                _width = gifWidth,
                _height = gifHeight
            }
        end
    end

    local gifCanvasRows = {}
    for gifY = 1, gifHeight do
        local gifRow = {}
        for gifX = 1, gifWidth do
            gifRow[gifX] = gifFillPixel
        end
        gifCanvasRows[gifY] = gifRow
    end
    return gifCanvasRows
end

local function assetBridgeGifFillCanvasRect(gifCanvasRows, gifCanvasWidth, gifCanvasHeight, gifRectX, gifRectY, gifRectWidth, gifRectHeight, gifFillPixel)
    local clippedStartX = math.max(0, gifRectX)
    local clippedStartY = math.max(0, gifRectY)
    local clippedEndX = math.min(gifCanvasWidth, gifRectX + gifRectWidth)
    local clippedEndY = math.min(gifCanvasHeight, gifRectY + gifRectHeight)
    local canvasBuffer = assetBridgeGifGetCanvasBuffer(gifCanvasRows)

    if canvasBuffer and assetBridgeBufferLibrary then
        local packedFillPixel = assetBridgeGifGetPackedPixel(gifFillPixel)
        for gifY = clippedStartY, clippedEndY - 1 do
            local pixelOffset = (gifY * gifCanvasWidth + clippedStartX) * 4
            for gifX = clippedStartX, clippedEndX - 1 do
                assetBridgeBufferLibrary.writeu32(canvasBuffer, pixelOffset, packedFillPixel)
                pixelOffset = pixelOffset + 4
            end
        end
        return
    end

    for gifY = clippedStartY, clippedEndY - 1 do
        local gifRow = gifCanvasRows[gifY + 1]
        for gifX = clippedStartX, clippedEndX - 1 do
            gifRow[gifX + 1] = gifFillPixel
        end
    end
end

local function assetBridgeGifPackUInt16LE(gifNumber)
    return string.char(gifNumber % 256, math.floor(gifNumber / 256) % 256)
end

local function assetBridgeGifPackUInt32BE(gifNumber)
    local highWord = math.floor(gifNumber / 65536)
    local lowWord = gifNumber % 65536
    return string.char(
        math.floor(highWord / 256) % 256,
        highWord % 256,
        math.floor(lowWord / 256) % 256,
        lowWord % 256
    )
end

local assetBridgeGifCRC32Table = nil

local function assetBridgeGifCRC32(gifBytes, yieldEveryBytes)
    if not bit32 then
        return nil, "GIF rendering requires the Luau bit32 library for PNG checksums."
    end

    if not assetBridgeGifCRC32Table then
        assetBridgeGifCRC32Table = {}
        for tableIndex = 0, 255 do
            local tableValue = tableIndex
            for checksumBit = 1, 8 do
                if bit32.band(tableValue, 1) == 1 then
                    tableValue = bit32.bxor(bit32.rshift(tableValue, 1), 3988292384)
                else
                    tableValue = bit32.rshift(tableValue, 1)
                end
            end
            assetBridgeGifCRC32Table[tableIndex] = tableValue
        end
    end

    local checksum = 4294967295

    for gifByteIndex = 1, #gifBytes do
        local tableLookupIndex = bit32.band(bit32.bxor(checksum, string.byte(gifBytes, gifByteIndex)), 255)
        if yieldEveryBytes and yieldEveryBytes > 0 and gifByteIndex % yieldEveryBytes == 0 then
            task.wait()
        end
        checksum = bit32.bxor(bit32.rshift(checksum, 8), assetBridgeGifCRC32Table[tableLookupIndex])
    end

    return bit32.bxor(checksum, 4294967295)
end

local function assetBridgeGifAdler32(gifBytes, yieldEveryBytes)
    local adlerA = 1
    local adlerB = 0

    for gifByteIndex = 1, #gifBytes do
        adlerA = adlerA + string.byte(gifBytes, gifByteIndex)
        adlerB = adlerB + adlerA

        if gifByteIndex % 5552 == 0 then
            adlerA = adlerA % 65521
            adlerB = adlerB % 65521
        end
        if yieldEveryBytes and yieldEveryBytes > 0 and gifByteIndex % yieldEveryBytes == 0 then
            task.wait()
        end
    end

    adlerA = adlerA % 65521
    adlerB = adlerB % 65521
    return adlerB * 65536 + adlerA
end

local function assetBridgeGifCreatePNGChunk(gifChunkType, gifChunkData, yieldEveryBytes)
    local chunkPayload = gifChunkType .. gifChunkData
    local chunkChecksum, checksumError = assetBridgeGifCRC32(chunkPayload, yieldEveryBytes)

    if not chunkChecksum then
        return nil, checksumError
    end

    return assetBridgeGifPackUInt32BE(#gifChunkData) .. chunkPayload .. assetBridgeGifPackUInt32BE(chunkChecksum)
end

local function assetBridgeGifReverseBits(value, bitCount)
    local reversedValue = 0
    for bitIndex = 1, bitCount do
        reversedValue = reversedValue * 2 + (value % 2)
        value = math.floor(value / 2)
    end
    return reversedValue
end

local assetBridgeGifFixedHuffmanCodes = {}
local assetBridgeGifFixedHuffmanLengths = {}
for fixedSymbol = 0, 287 do
    local fixedCodeValue
    local fixedCodeLength
    if fixedSymbol <= 143 then
        fixedCodeValue = 48 + fixedSymbol
        fixedCodeLength = 8
    elseif fixedSymbol <= 255 then
        fixedCodeValue = 400 + fixedSymbol - 144
        fixedCodeLength = 9
    elseif fixedSymbol <= 279 then
        fixedCodeValue = fixedSymbol - 256
        fixedCodeLength = 7
    else
        fixedCodeValue = 192 + fixedSymbol - 280
        fixedCodeLength = 8
    end
    assetBridgeGifFixedHuffmanCodes[fixedSymbol] = assetBridgeGifReverseBits(fixedCodeValue, fixedCodeLength)
    assetBridgeGifFixedHuffmanLengths[fixedSymbol] = fixedCodeLength
end

local function assetBridgeGifEncodeZlib(gifRawImageBytes, yieldEveryBytes, useFastCompression)
    local outputBytes = {}
    local bitBuffer = 0
    local bitCount = 0
    local processedByteCount = 0
    local nextYieldAt = yieldEveryBytes and yieldEveryBytes > 0 and yieldEveryBytes or math.huge

    local function writeBits(value, count)
        if count <= 0 then return end
        bitBuffer = bitBuffer + (value % (2 ^ count)) * (2 ^ bitCount)
        bitCount = bitCount + count
        while bitCount >= 8 do
            outputBytes[#outputBytes + 1] = string.char(bitBuffer % 256)
            bitBuffer = math.floor(bitBuffer / 256)
            bitCount = bitCount - 8
        end
    end

    local function writeSymbol(symbol)
        writeBits(assetBridgeGifFixedHuffmanCodes[symbol], assetBridgeGifFixedHuffmanLengths[symbol])
    end

    local lengthBases = {3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258}
    local lengthExtraBits = {0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0}
    local distanceBases = {1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577}
    local distanceExtraBits = {0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13}

    local function writeLengthDistance(matchLength, matchDistance)
        local lengthCodeIndex = 1
        while lengthCodeIndex < #lengthBases do
            local extraCount = lengthExtraBits[lengthCodeIndex]
            if matchLength < lengthBases[lengthCodeIndex] + (2 ^ extraCount) then break end
            lengthCodeIndex = lengthCodeIndex + 1
        end
        writeSymbol(256 + lengthCodeIndex)
        local lengthExtraCount = lengthExtraBits[lengthCodeIndex]
        if lengthExtraCount > 0 then
            writeBits(matchLength - lengthBases[lengthCodeIndex], lengthExtraCount)
        end

        local distanceCodeIndex = 1
        while distanceCodeIndex < #distanceBases do
            local extraCount = distanceExtraBits[distanceCodeIndex]
            if matchDistance < distanceBases[distanceCodeIndex] + (2 ^ extraCount) then break end
            distanceCodeIndex = distanceCodeIndex + 1
        end
        writeBits(assetBridgeGifReverseBits(distanceCodeIndex - 1, 5), 5)
        local distanceExtraCount = distanceExtraBits[distanceCodeIndex]
        if distanceExtraCount > 0 then
            writeBits(matchDistance - distanceBases[distanceCodeIndex], distanceExtraCount)
        end
    end

    writeBits(1, 1)
    writeBits(1, 2)

    local rawByteCount = #gifRawImageBytes
    if useFastCompression then
        local rawPosition = 1
        while rawPosition <= rawByteCount do
            local runByte = string.byte(gifRawImageBytes, rawPosition)
            local runEndPosition = rawPosition + 1
            while runEndPosition <= rawByteCount
                and string.byte(gifRawImageBytes, runEndPosition) == runByte do
                runEndPosition = runEndPosition + 1
            end

            local runLength = runEndPosition - rawPosition
            if runLength >= 4 then
                writeSymbol(runByte)
                local remainingRunLength = runLength - 1
                while remainingRunLength >= 3 do
                    local matchLength = math.min(258, remainingRunLength)
                    writeLengthDistance(matchLength, 1)
                    remainingRunLength = remainingRunLength - matchLength
                end
                while remainingRunLength > 0 do
                    writeSymbol(runByte)
                    remainingRunLength = remainingRunLength - 1
                end
            else
                for runByteIndex = 1, runLength do
                    writeSymbol(runByte)
                end
            end

            rawPosition = runEndPosition
            processedByteCount = processedByteCount + runLength
            if yieldEveryBytes and yieldEveryBytes > 0 and processedByteCount >= nextYieldAt then
                task.wait()
                nextYieldAt = nextYieldAt + yieldEveryBytes
            end
        end
    else
        local latestPositionBySequence = {}
        local rawPosition = 1
        while rawPosition <= rawByteCount do
            local matchedLength = 0
            local matchedDistance = 0
            local sequenceKey
            if rawPosition + 2 <= rawByteCount then
                local sequenceByteOne, sequenceByteTwo, sequenceByteThree = string.byte(gifRawImageBytes, rawPosition, rawPosition + 2)
                sequenceKey = (sequenceByteOne * 251 + sequenceByteTwo * 31 + sequenceByteThree) % 65536
                local previousPosition = latestPositionBySequence[sequenceKey]
                if previousPosition and rawPosition - previousPosition <= 32768 then
                    local maximumMatchLength = math.min(258, rawByteCount - rawPosition + 1)
                    while matchedLength < maximumMatchLength
                        and string.byte(gifRawImageBytes, previousPosition + matchedLength) == string.byte(gifRawImageBytes, rawPosition + matchedLength) do
                        matchedLength = matchedLength + 1
                    end
                    if matchedLength >= 3 then
                        matchedDistance = rawPosition - previousPosition
                    else
                        matchedLength = 0
                    end
                end
            end

            if matchedLength >= 3 then
                writeLengthDistance(matchedLength, matchedDistance)
                local matchEndPosition = rawPosition + matchedLength - 1
                while rawPosition <= matchEndPosition do
                    if rawPosition + 2 <= rawByteCount then
                        local sequenceByteOne, sequenceByteTwo, sequenceByteThree = string.byte(gifRawImageBytes, rawPosition, rawPosition + 2)
                        local sequenceHash = (sequenceByteOne * 251 + sequenceByteTwo * 31 + sequenceByteThree) % 65536
                        latestPositionBySequence[sequenceHash] = rawPosition
                    end
                    rawPosition = rawPosition + 1
                end
                processedByteCount = processedByteCount + matchedLength
            else
                writeSymbol(string.byte(gifRawImageBytes, rawPosition))
                if sequenceKey then latestPositionBySequence[sequenceKey] = rawPosition end
                rawPosition = rawPosition + 1
                processedByteCount = processedByteCount + 1
            end

            if yieldEveryBytes and yieldEveryBytes > 0 and processedByteCount >= nextYieldAt then
                task.wait()
                nextYieldAt = nextYieldAt + yieldEveryBytes
            end
        end
    end

    writeSymbol(256)
    if bitCount > 0 then outputBytes[#outputBytes + 1] = string.char(bitBuffer % 256) end

    local deflateBytes = table.concat(outputBytes)
    return string.char(120, 156) .. deflateBytes .. assetBridgeGifPackUInt32BE(assetBridgeGifAdler32(gifRawImageBytes, yieldEveryBytes))
end
local assetBridgeGifSingleByteStrings = {}
for gifByteValue = 0, 255 do
    assetBridgeGifSingleByteStrings[gifByteValue] = string.char(gifByteValue)
end

local function assetBridgeGifEncodeTrueColorPNG(gifWidth, gifHeight, gifCanvasRows, yieldEveryRows)
    local canvasBuffer = assetBridgeGifGetCanvasBuffer(gifCanvasRows)
    local rawImageBuffer = nil
    local pngScanlines = nil
    local pngRowStride = gifWidth * 4 + 1

    if assetBridgeBufferLibrary
        and type(assetBridgeBufferLibrary.create) == "function"
        and type(assetBridgeBufferLibrary.writeu8) == "function"
        and type(assetBridgeBufferLibrary.tostring) == "function" then
        local outputBufferSuccess, outputBuffer = pcall(assetBridgeBufferLibrary.create, pngRowStride * gifHeight)
        if outputBufferSuccess then
            rawImageBuffer = outputBuffer
        end
    end

    if not rawImageBuffer then
        pngScanlines = {}
    end

    local pngRowOffset = 0
    for gifY = 1, gifHeight do
        local rgbaRowBytes
        if canvasBuffer and assetBridgeBufferLibrary then
            rgbaRowBytes = assetBridgeBufferLibrary.readstring(canvasBuffer, (gifY - 1) * gifWidth * 4, gifWidth * 4)
        else
            rgbaRowBytes = table.concat(gifCanvasRows[gifY])
        end

        if rawImageBuffer then
            assetBridgeBufferLibrary.writeu8(rawImageBuffer, pngRowOffset, 1)
            for rgbaByteIndex = 1, #rgbaRowBytes do
                local rgbaByteValue = string.byte(rgbaRowBytes, rgbaByteIndex)
                local rgbaLeftByte = rgbaByteIndex > 4 and string.byte(rgbaRowBytes, rgbaByteIndex - 4) or 0
                assetBridgeBufferLibrary.writeu8(rawImageBuffer, pngRowOffset + rgbaByteIndex, (rgbaByteValue - rgbaLeftByte) % 256)
            end
        else
            local filteredRowParts = {"\1"}
            for rgbaByteIndex = 1, #rgbaRowBytes do
                local rgbaByteValue = string.byte(rgbaRowBytes, rgbaByteIndex)
                local rgbaLeftByte = rgbaByteIndex > 4 and string.byte(rgbaRowBytes, rgbaByteIndex - 4) or 0
                filteredRowParts[#filteredRowParts + 1] = assetBridgeGifSingleByteStrings[(rgbaByteValue - rgbaLeftByte) % 256]
            end
            pngScanlines[#pngScanlines + 1] = table.concat(filteredRowParts)
        end

        pngRowOffset = pngRowOffset + pngRowStride
        if yieldEveryRows and yieldEveryRows > 0 and gifY % yieldEveryRows == 0 then
            task.wait()
        end
    end

    local rawImageBytes = rawImageBuffer and assetBridgeBufferLibrary.tostring(rawImageBuffer) or table.concat(pngScanlines)
    local yieldEveryBytes = yieldEveryRows and yieldEveryRows > 0 and math.max(4096, yieldEveryRows * gifWidth * 4) or nil
    local compressedImageBytes = assetBridgeGifEncodeZlib(rawImageBytes, yieldEveryBytes)
    local pngHeaderData = assetBridgeGifPackUInt32BE(gifWidth)
        .. assetBridgeGifPackUInt32BE(gifHeight)
        .. string.char(8, 6, 0, 0, 0)

    local headerChunk, headerError = assetBridgeGifCreatePNGChunk("IHDR", pngHeaderData, yieldEveryBytes)
    if not headerChunk then
        return nil, headerError
    end

    local imageChunk, imageError = assetBridgeGifCreatePNGChunk("IDAT", compressedImageBytes, yieldEveryBytes)
    if not imageChunk then
        return nil, imageError
    end

    local endChunk, endError = assetBridgeGifCreatePNGChunk("IEND", "", yieldEveryBytes)
    if not endChunk then
        return nil, endError
    end

    return "\137PNG\r\n\26\n" .. headerChunk .. imageChunk .. endChunk, nil, "rgba"
end

local function assetBridgeGifEncodeIndexedPNG(gifWidth, gifHeight, gifCanvasRows, yieldEveryRows)
    local paletteIndexes = {}
    local paletteRedGreenBlue = {}
    local paletteAlpha = {}
    local paletteCount = 0
    local lastTransparentPaletteIndex = 0
    local indexedScanlines = nil
    local canvasBuffer = assetBridgeGifGetCanvasBuffer(gifCanvasRows)
    local indexedRowStride = gifWidth + 1
    local indexedImageBuffer = nil

    if assetBridgeBufferLibrary
        and type(assetBridgeBufferLibrary.create) == "function"
        and type(assetBridgeBufferLibrary.writeu8) == "function"
        and type(assetBridgeBufferLibrary.tostring) == "function" then
        local outputBufferSuccess, outputBuffer = pcall(assetBridgeBufferLibrary.create, indexedRowStride * gifHeight)
        if outputBufferSuccess then
            indexedImageBuffer = outputBuffer
        end
    end

    if not indexedImageBuffer then
        indexedScanlines = {}
    end

    local indexedRowOffset = 0
    for gifY = 1, gifHeight do
        local indexedRowParts = indexedImageBuffer and nil or {}
        local previousPaletteIndex = 0
        local canvasRow = not canvasBuffer and gifCanvasRows[gifY] or nil

        if indexedImageBuffer then
            assetBridgeBufferLibrary.writeu8(indexedImageBuffer, indexedRowOffset, 1)
        end

        for gifX = 1, gifWidth do
            local rgbaPixel
            if canvasBuffer and assetBridgeBufferLibrary then
                rgbaPixel = assetBridgeBufferLibrary.readu32(canvasBuffer, ((gifY - 1) * gifWidth + gifX - 1) * 4)
            else
                rgbaPixel = canvasRow[gifX]
            end
            local paletteIndex = paletteIndexes[rgbaPixel]

            if paletteIndex == nil then
                if paletteCount >= 256 then
                    return nil, "The composed GIF frame uses more than 256 colors."
                end

                paletteCount = paletteCount + 1
                paletteIndex = paletteCount
                paletteIndexes[rgbaPixel] = paletteIndex

                local redValue, greenValue, blueValue, alphaValue
                if canvasBuffer then
                    redValue = rgbaPixel % 256
                    greenValue = math.floor(rgbaPixel / 256) % 256
                    blueValue = math.floor(rgbaPixel / 65536) % 256
                    alphaValue = math.floor(rgbaPixel / 16777216) % 256
                else
                    redValue, greenValue, blueValue, alphaValue = string.byte(rgbaPixel, 1, 4)
                end
                paletteRedGreenBlue[paletteCount] = string.char(redValue, greenValue, blueValue)
                paletteAlpha[paletteCount] = string.char(alphaValue)
                if alphaValue ~= 255 then
                    lastTransparentPaletteIndex = paletteCount
                end
            end

            local zeroBasedPaletteIndex = paletteIndex - 1
            local subFilteredPaletteIndex = (zeroBasedPaletteIndex - previousPaletteIndex) % 256
            if indexedImageBuffer then
                assetBridgeBufferLibrary.writeu8(indexedImageBuffer, indexedRowOffset + gifX, subFilteredPaletteIndex)
            else
                indexedRowParts[#indexedRowParts + 1] = assetBridgeGifSingleByteStrings[subFilteredPaletteIndex]
            end
            previousPaletteIndex = zeroBasedPaletteIndex
        end

        if not indexedImageBuffer then
            indexedScanlines[#indexedScanlines + 1] = "\1" .. table.concat(indexedRowParts)
        end
        indexedRowOffset = indexedRowOffset + indexedRowStride
        if yieldEveryRows and yieldEveryRows > 0 and gifY % yieldEveryRows == 0 then
            task.wait()
        end
    end

    local rawImageBytes = indexedImageBuffer and assetBridgeBufferLibrary.tostring(indexedImageBuffer) or table.concat(indexedScanlines)
    local yieldEveryBytes = yieldEveryRows and yieldEveryRows > 0 and math.max(4096, yieldEveryRows * gifWidth) or nil
    local compressedImageBytes = assetBridgeGifEncodeZlib(rawImageBytes, yieldEveryBytes)
    local pngHeaderData = assetBridgeGifPackUInt32BE(gifWidth)
        .. assetBridgeGifPackUInt32BE(gifHeight)
        .. string.char(8, 3, 0, 0, 0)

    local headerChunk, headerError = assetBridgeGifCreatePNGChunk("IHDR", pngHeaderData, yieldEveryBytes)
    if not headerChunk then
        return nil, headerError
    end

    local paletteChunk, paletteError = assetBridgeGifCreatePNGChunk("PLTE", table.concat(paletteRedGreenBlue), yieldEveryBytes)
    if not paletteChunk then
        return nil, paletteError
    end

    local transparencyChunk = ""
    if lastTransparentPaletteIndex > 0 then
        local transparencyData = {}
        for paletteIndex = 1, lastTransparentPaletteIndex do
            transparencyData[paletteIndex] = paletteAlpha[paletteIndex]
        end
        local createdTransparencyChunk, transparencyError = assetBridgeGifCreatePNGChunk("tRNS", table.concat(transparencyData), yieldEveryBytes)
        if not createdTransparencyChunk then
            return nil, transparencyError
        end
        transparencyChunk = createdTransparencyChunk
    end

    local imageChunk, imageError = assetBridgeGifCreatePNGChunk("IDAT", compressedImageBytes, yieldEveryBytes)
    if not imageChunk then
        return nil, imageError
    end

    local endChunk, endError = assetBridgeGifCreatePNGChunk("IEND", "", yieldEveryBytes)
    if not endChunk then
        return nil, endError
    end

    return "\137PNG\r\n\26\n" .. headerChunk .. paletteChunk .. transparencyChunk .. imageChunk .. endChunk, "indexed"
end

local function assetBridgeGifEncodePNG(gifWidth, gifHeight, gifCanvasRows, yieldEveryRows)
    local indexedPngBytes, indexedPngModeOrError = assetBridgeGifEncodeIndexedPNG(
        gifWidth,
        gifHeight,
        gifCanvasRows,
        yieldEveryRows
    )

    if indexedPngBytes then
        return indexedPngBytes, nil, indexedPngModeOrError
    end

    if indexedPngModeOrError ~= "The composed GIF frame uses more than 256 colors." then
        return nil, indexedPngModeOrError
    end

    return assetBridgeGifEncodeTrueColorPNG(gifWidth, gifHeight, gifCanvasRows, yieldEveryRows)
end

local function assetBridgeGifDecode(gifBytes, gifOptions)
    gifOptions = gifOptions or {}

    if type(gifBytes) ~= "string" or (string.sub(gifBytes, 1, 6) ~= "GIF87a" and string.sub(gifBytes, 1, 6) ~= "GIF89a") then
        return nil, "The downloaded file is not a valid GIF87a/GIF89a image."
    end

    if not bit32 then
        return nil, "GIF decoding requires the Luau bit32 library."
    end

    local gifPosition = 7
    local gifCanvasWidth = assetBridgeGifReadUInt16(gifBytes, gifPosition)
    local gifCanvasHeight = assetBridgeGifReadUInt16(gifBytes, gifPosition + 2)
    if not gifCanvasWidth or not gifCanvasHeight then
        return nil, "GIF logical screen descriptor is incomplete."
    end
    gifPosition = gifPosition + 4

    local gifScreenPacked, gifBackgroundIndex = string.byte(gifBytes, gifPosition, gifPosition + 1)
    if not gifScreenPacked or not gifBackgroundIndex then
        return nil, "GIF logical screen descriptor is incomplete."
    end
    gifPosition = gifPosition + 3

    if gifCanvasWidth < 1 or gifCanvasHeight < 1 then
        return nil, "GIF dimensions must be greater than zero."
    end

    local logicalScreenPixels = gifCanvasWidth * gifCanvasHeight

    local globalColorTable = nil
    local globalColorCount = 0
    if bit32.band(gifScreenPacked, 128) ~= 0 then
        globalColorCount = 2 ^ (bit32.band(gifScreenPacked, 7) + 1)
        local colorTableError
        globalColorTable, gifPosition, colorTableError = assetBridgeGifReadColorTable(gifBytes, gifPosition, globalColorCount)
        if not globalColorTable then
            return nil, colorTableError
        end
    end

    local transparentPixel = string.char(0, 0, 0, 0)
    local backgroundPixel = globalColorTable and globalColorTable[gifBackgroundIndex] or transparentPixel
    local gifCanvasRows = assetBridgeGifCreateCanvas(gifCanvasWidth, gifCanvasHeight, backgroundPixel)
    local gifFrames = {}
    local gifTotalPixels = 0
    local gifTotalOutputBytes = 0
    local gifGraphicControl = {
        Delay = 0,
        Disposal = 0,
        Transparent = false,
        TransparentIndex = nil
    }
    local previousGraphicFrame = nil
    local gifLoopExtensionFound = false
    local gifLoopCount = nil

    while gifPosition <= #gifBytes do
        local blockIntroducer = string.byte(gifBytes, gifPosition)
        gifPosition = gifPosition + 1

        if blockIntroducer == 59 then
            break
        elseif blockIntroducer == 33 then
            local extensionLabel = string.byte(gifBytes, gifPosition)
            if not extensionLabel then
                return nil, "GIF extension is incomplete."
            end
            gifPosition = gifPosition + 1

            if extensionLabel == 249 then
                local graphicControlBlockSize = string.byte(gifBytes, gifPosition)
                if not graphicControlBlockSize then
                    return nil, "GIF graphic control extension is incomplete."
                end
                if graphicControlBlockSize ~= 4 then
                    return nil, "GIF graphic control extension has an invalid block size."
                end
                gifPosition = gifPosition + 1

                if gifPosition + graphicControlBlockSize - 1 > #gifBytes then
                    return nil, "GIF graphic control extension exceeds the file."
                end

                local graphicControlPacked = string.byte(gifBytes, gifPosition) or 0
                local graphicControlDelay = assetBridgeGifReadUInt16(gifBytes, gifPosition + 1) or 0
                local graphicControlTransparentIndex = string.byte(gifBytes, gifPosition + 3)

                gifGraphicControl.Disposal = bit32.band(bit32.rshift(graphicControlPacked, 2), 7)
                gifGraphicControl.Delay = graphicControlDelay
                gifGraphicControl.Transparent = bit32.band(graphicControlPacked, 1) ~= 0
                gifGraphicControl.TransparentIndex = gifGraphicControl.Transparent and graphicControlTransparentIndex or nil

                if #gifFrames == 0 and gifGraphicControl.Transparent then
                    gifCanvasRows = assetBridgeGifCreateCanvas(gifCanvasWidth, gifCanvasHeight, transparentPixel)
                end

                gifPosition = gifPosition + graphicControlBlockSize
                if string.byte(gifBytes, gifPosition) == 0 then
                    gifPosition = gifPosition + 1
                end
            elseif extensionLabel == 255 then
                local applicationHeaderSize = string.byte(gifBytes, gifPosition)
                if not applicationHeaderSize then
                    return nil, "GIF application extension is incomplete."
                end
                gifPosition = gifPosition + 1

                local applicationIdentifier = string.sub(gifBytes, gifPosition, gifPosition + applicationHeaderSize - 1)
                gifPosition = gifPosition + applicationHeaderSize

                local applicationData, nextGifPosition, applicationError = assetBridgeGifReadSubBlocks(gifBytes, gifPosition)
                if not applicationData then
                    return nil, applicationError
                end
                gifPosition = nextGifPosition

                if (applicationIdentifier == "NETSCAPE2.0" or applicationIdentifier == "ANIMEXTS1.0") and #applicationData >= 3 and string.byte(applicationData, 1) == 1 then
                    gifLoopExtensionFound = true
                    gifLoopCount = string.byte(applicationData, 2) + string.byte(applicationData, 3) * 256
                end
            else
                if extensionLabel == 1 then
                    local plainTextHeaderSize = string.byte(gifBytes, gifPosition)
                    if not plainTextHeaderSize then
                        return nil, "GIF plain-text extension is incomplete."
                    end
                    gifPosition = gifPosition + 1 + plainTextHeaderSize
                end

                local ignoredExtensionData, nextGifPosition, extensionError = assetBridgeGifReadSubBlocks(gifBytes, gifPosition)
                if not ignoredExtensionData then
                    return nil, extensionError
                end
                gifPosition = nextGifPosition
            end
        elseif blockIntroducer == 44 then
            if previousGraphicFrame then
                if previousGraphicFrame.Disposal == 2 then
                    local disposalFillPixel = previousGraphicFrame.Transparent and transparentPixel or backgroundPixel
                    assetBridgeGifFillCanvasRect(
                        gifCanvasRows,
                        gifCanvasWidth,
                        gifCanvasHeight,
                        previousGraphicFrame.X,
                        previousGraphicFrame.Y,
                        previousGraphicFrame.Width,
                        previousGraphicFrame.Height,
                        disposalFillPixel
                    )
                elseif previousGraphicFrame.Disposal == 3 then
                    gifCanvasRows = previousGraphicFrame.Restore
                end
                previousGraphicFrame = nil
            end

            local frameX = assetBridgeGifReadUInt16(gifBytes, gifPosition)
            local frameY = assetBridgeGifReadUInt16(gifBytes, gifPosition + 2)
            local frameWidth = assetBridgeGifReadUInt16(gifBytes, gifPosition + 4)
            local frameHeight = assetBridgeGifReadUInt16(gifBytes, gifPosition + 6)
            if not frameX or not frameY or not frameWidth or not frameHeight then
                return nil, "GIF image descriptor is incomplete."
            end
            gifPosition = gifPosition + 8

            local imagePacked = string.byte(gifBytes, gifPosition)
            if not imagePacked then
                return nil, "GIF image descriptor is incomplete."
            end
            gifPosition = gifPosition + 1

            if frameWidth < 1 or frameHeight < 1 then
                return nil, "GIF frame dimensions must be greater than zero."
            end

            local framePixelCount = frameWidth * frameHeight
            gifTotalPixels = gifTotalPixels + logicalScreenPixels


            local localColorTable = nil
            local localColorCount = 0
            if bit32.band(imagePacked, 128) ~= 0 then
                localColorCount = 2 ^ (bit32.band(imagePacked, 7) + 1)
                local localColorTableError
                localColorTable, gifPosition, localColorTableError = assetBridgeGifReadColorTable(gifBytes, gifPosition, localColorCount)
                if not localColorTable then
                    return nil, localColorTableError
                end
            end

            local frameColorTable = localColorTable or globalColorTable
            if not frameColorTable then
                return nil, "GIF frame has no global or local color table."
            end

            local lzwMinimumCodeSize = string.byte(gifBytes, gifPosition)
            if not lzwMinimumCodeSize then
                return nil, "GIF image data is incomplete."
            end
            gifPosition = gifPosition + 1

            local compressedFrameData, nextFramePosition, compressedFrameError = assetBridgeGifReadSubBlocks(gifBytes, gifPosition)
            if not compressedFrameData then
                return nil, compressedFrameError
            end
            gifPosition = nextFramePosition

            local decodedFramePixels, frameDecodeError = assetBridgeGifDecodeLZW(compressedFrameData, lzwMinimumCodeSize, framePixelCount)
            if not decodedFramePixels then
                return nil, frameDecodeError
            end

            local previousFrameRestore = assetBridgeGifCloneCanvas(gifCanvasRows, gifCanvasHeight)
            local reorderedFramePixels = {}
            local frameSourceRow = 0

            if bit32.band(imagePacked, 64) ~= 0 then
                local interlacePasses = {
                    {Start = 0, Step = 8},
                    {Start = 4, Step = 8},
                    {Start = 2, Step = 4},
                    {Start = 1, Step = 2}
                }

                for _, interlacePass in ipairs(interlacePasses) do
                    local destinationY = interlacePass.Start
                    while destinationY < frameHeight do
                        local destinationRow = {}
                        for frameXPosition = 1, frameWidth do
                            frameSourceRow = frameSourceRow + 1
                            destinationRow[frameXPosition] = string.byte(decodedFramePixels, frameSourceRow)
                        end
                        reorderedFramePixels[destinationY + 1] = destinationRow
                        destinationY = destinationY + interlacePass.Step
                    end
                end
            else
                for destinationY = 1, frameHeight do
                    local destinationRow = {}
                    for frameXPosition = 1, frameWidth do
                        frameSourceRow = frameSourceRow + 1
                        destinationRow[frameXPosition] = string.byte(decodedFramePixels, frameSourceRow)
                    end
                    reorderedFramePixels[destinationY] = destinationRow
                end
            end

            local frameStartY = math.max(0, frameY)
            local frameEndY = math.min(gifCanvasHeight, frameY + frameHeight)
            local frameStartX = math.max(0, frameX)
            local frameEndX = math.min(gifCanvasWidth, frameX + frameWidth)

            for canvasY = frameStartY, frameEndY - 1 do
                local destinationCanvasRow = {}
                local previousCanvasRow = gifCanvasRows[canvasY + 1]
                for canvasX = 1, gifCanvasWidth do
                    destinationCanvasRow[canvasX] = previousCanvasRow[canvasX]
                end

                local localFrameY = canvasY - frameY + 1
                local sourceFrameRow = reorderedFramePixels[localFrameY]
                if sourceFrameRow then
                    for canvasX = frameStartX, frameEndX - 1 do
                        local localFrameX = canvasX - frameX + 1
                        local colorIndex = sourceFrameRow[localFrameX]

                        if colorIndex ~= nil and colorIndex ~= gifGraphicControl.TransparentIndex then
                            local rgbaPixel = frameColorTable[colorIndex]
                            if not rgbaPixel then
                                return nil, "GIF frame references a color that is missing from its palette."
                            end
                            destinationCanvasRow[canvasX + 1] = rgbaPixel
                        end
                    end
                end

                gifCanvasRows[canvasY + 1] = destinationCanvasRow
            end

            local pngFrameBytes, pngFrameError = assetBridgeGifEncodePNG(gifCanvasWidth, gifCanvasHeight, gifCanvasRows)
            if not pngFrameBytes then
                return nil, pngFrameError
            end

            gifTotalOutputBytes = gifTotalOutputBytes + #pngFrameBytes

            local frameDelaySeconds = gifGraphicControl.Delay / 100
            if frameDelaySeconds <= 0 then
                frameDelaySeconds = 0.1
            end
            frameDelaySeconds = math.max(frameDelaySeconds, tonumber(gifOptions.MinFrameDelay) or tonumber(AssetBridge.Config.GIFMinFrameDelay) or 0.02)

            gifFrames[#gifFrames + 1] = {
                Index = #gifFrames + 1,
                Bytes = pngFrameBytes,
                Duration = frameDelaySeconds,
                X = frameX,
                Y = frameY,
                Width = frameWidth,
                Height = frameHeight
            }

            previousGraphicFrame = {
                Disposal = gifGraphicControl.Disposal,
                X = frameX,
                Y = frameY,
                Width = frameWidth,
                Height = frameHeight,
                Transparent = gifGraphicControl.Transparent,
                Restore = previousFrameRestore
            }

            gifGraphicControl = {
                Delay = 0,
                Disposal = 0,
                Transparent = false,
                TransparentIndex = nil
            }
        elseif blockIntroducer == 0 then
            -- Ignore harmless zero padding between GIF blocks.
        else
            return nil, "GIF contains an unknown block marker at byte " .. tostring(gifPosition - 1) .. "."
        end

    end

    if #gifFrames == 0 then
        return nil, "The GIF did not contain any image frames."
    end

    return {
        Width = gifCanvasWidth,
        Height = gifCanvasHeight,
        Frames = gifFrames,
        FrameCount = #gifFrames,
        LoopExtensionFound = gifLoopExtensionFound,
        LoopCount = gifLoopCount,
        TotalPixels = gifTotalPixels,
        TotalOutputBytes = gifTotalOutputBytes
    }
end

local assetBridgeGifDecoderMethods = {}

local function assetBridgeGifScanFrames(gifBytes, gifOptions)
    gifOptions = gifOptions or {}

    if type(gifBytes) ~= "string" or (string.sub(gifBytes, 1, 6) ~= "GIF87a" and string.sub(gifBytes, 1, 6) ~= "GIF89a") then
        return nil, "The downloaded file is not a valid GIF87a/GIF89a image."
    end

    if not bit32 then
        return nil, "GIF decoding requires the Luau bit32 library."
    end

    local gifPosition = 7
    local gifCanvasWidth = assetBridgeGifReadUInt16(gifBytes, gifPosition)
    local gifCanvasHeight = assetBridgeGifReadUInt16(gifBytes, gifPosition + 2)
    if not gifCanvasWidth or not gifCanvasHeight then
        return nil, "GIF logical screen descriptor is incomplete."
    end
    gifPosition = gifPosition + 4

    local gifScreenPacked, gifBackgroundIndex = string.byte(gifBytes, gifPosition, gifPosition + 1)
    if not gifScreenPacked or not gifBackgroundIndex then
        return nil, "GIF logical screen descriptor is incomplete."
    end
    gifPosition = gifPosition + 3

    if gifCanvasWidth < 1 or gifCanvasHeight < 1 then
        return nil, "GIF dimensions must be greater than zero."
    end

    local logicalScreenPixels = gifCanvasWidth * gifCanvasHeight

    local globalColorTable = nil
    local globalColorCount = 0
    if bit32.band(gifScreenPacked, 128) ~= 0 then
        globalColorCount = 2 ^ (bit32.band(gifScreenPacked, 7) + 1)
        local globalColorTableError
        globalColorTable, gifPosition, globalColorTableError = assetBridgeGifReadColorTable(gifBytes, gifPosition, globalColorCount)
        if not globalColorTable then
            return nil, globalColorTableError
        end
    end

    local gifFrames = {}
    local gifGraphicControl = {
        Delay = 0,
        Disposal = 0,
        Transparent = false,
        TransparentIndex = nil
    }
    local gifLoopExtensionFound = false
    local gifLoopCount = nil
    local gifTotalPixels = 0

    while gifPosition <= #gifBytes do
        local blockIntroducer = string.byte(gifBytes, gifPosition)
        gifPosition = gifPosition + 1

        if blockIntroducer == 59 then
            break
        elseif blockIntroducer == 33 then
            local extensionLabel = string.byte(gifBytes, gifPosition)
            if not extensionLabel then
                return nil, "GIF extension is incomplete."
            end
            gifPosition = gifPosition + 1

            if extensionLabel == 249 then
                local controlBlockSize = string.byte(gifBytes, gifPosition)
                if controlBlockSize ~= 4 then
                    return nil, "GIF graphic control extension has an invalid block size."
                end
                gifPosition = gifPosition + 1
                if gifPosition + 3 > #gifBytes then
                    return nil, "GIF graphic control extension exceeds the file."
                end

                local controlPacked = string.byte(gifBytes, gifPosition) or 0
                local controlDelay = assetBridgeGifReadUInt16(gifBytes, gifPosition + 1) or 0
                local transparentIndex = string.byte(gifBytes, gifPosition + 3)
                gifGraphicControl.Disposal = bit32.band(bit32.rshift(controlPacked, 2), 7)
                gifGraphicControl.Delay = controlDelay
                gifGraphicControl.Transparent = bit32.band(controlPacked, 1) ~= 0
                gifGraphicControl.TransparentIndex = gifGraphicControl.Transparent and transparentIndex or nil
                gifPosition = gifPosition + 4
                if string.byte(gifBytes, gifPosition) == 0 then
                    gifPosition = gifPosition + 1
                end
            elseif extensionLabel == 255 then
                local applicationHeaderSize = string.byte(gifBytes, gifPosition)
                if not applicationHeaderSize then
                    return nil, "GIF application extension is incomplete."
                end
                gifPosition = gifPosition + 1
                local applicationIdentifier = string.sub(gifBytes, gifPosition, gifPosition + applicationHeaderSize - 1)
                gifPosition = gifPosition + applicationHeaderSize
                local applicationData, nextPosition, applicationError = assetBridgeGifReadSubBlocks(gifBytes, gifPosition)
                if not applicationData then
                    return nil, applicationError
                end
                gifPosition = nextPosition

                if (applicationIdentifier == "NETSCAPE2.0" or applicationIdentifier == "ANIMEXTS1.0") and #applicationData >= 3 and string.byte(applicationData, 1) == 1 then
                    gifLoopExtensionFound = true
                    gifLoopCount = string.byte(applicationData, 2) + string.byte(applicationData, 3) * 256
                end
            else
                if extensionLabel == 1 then
                    local plainTextHeaderSize = string.byte(gifBytes, gifPosition)
                    if not plainTextHeaderSize then
                        return nil, "GIF plain-text extension is incomplete."
                    end
                    gifPosition = gifPosition + 1 + plainTextHeaderSize
                end

                local ignoredExtensionData, nextPosition, extensionError = assetBridgeGifReadSubBlocks(gifBytes, gifPosition)
                if not ignoredExtensionData then
                    return nil, extensionError
                end
                gifPosition = nextPosition
            end
        elseif blockIntroducer == 44 then
            local frameX = assetBridgeGifReadUInt16(gifBytes, gifPosition)
            local frameY = assetBridgeGifReadUInt16(gifBytes, gifPosition + 2)
            local frameWidth = assetBridgeGifReadUInt16(gifBytes, gifPosition + 4)
            local frameHeight = assetBridgeGifReadUInt16(gifBytes, gifPosition + 6)
            if not frameX or not frameY or not frameWidth or not frameHeight then
                return nil, "GIF image descriptor is incomplete."
            end
            gifPosition = gifPosition + 8

            local imagePacked = string.byte(gifBytes, gifPosition)
            if not imagePacked then
                return nil, "GIF image descriptor is incomplete."
            end
            gifPosition = gifPosition + 1

            if frameWidth < 1 or frameHeight < 1 then
                return nil, "GIF frame dimensions must be greater than zero."
            end

            local framePixelCount = frameWidth * frameHeight
            gifTotalPixels = gifTotalPixels + logicalScreenPixels

            local localColorTable = nil
            local localColorCount = 0
            if bit32.band(imagePacked, 128) ~= 0 then
                localColorCount = 2 ^ (bit32.band(imagePacked, 7) + 1)
                local localColorTableError
                localColorTable, gifPosition, localColorTableError = assetBridgeGifReadColorTable(gifBytes, gifPosition, localColorCount)
                if not localColorTable then
                    return nil, localColorTableError
                end
            end

            local frameColorTable = localColorTable or globalColorTable
            if not frameColorTable then
                return nil, "GIF frame has no global or local color table."
            end

            local lzwMinimumCodeSize = string.byte(gifBytes, gifPosition)
            if not lzwMinimumCodeSize then
                return nil, "GIF image data is incomplete."
            end
            gifPosition = gifPosition + 1

            local compressedFrameData, nextPosition, compressedFrameError = assetBridgeGifReadSubBlocks(gifBytes, gifPosition)
            if not compressedFrameData then
                return nil, compressedFrameError
            end
            gifPosition = nextPosition

            local frameDelaySeconds = gifGraphicControl.Delay / 100
            if frameDelaySeconds <= 0 then
                frameDelaySeconds = 0.1
            end
            frameDelaySeconds = math.max(frameDelaySeconds, tonumber(gifOptions.MinFrameDelay) or tonumber(AssetBridge.Config.GIFMinFrameDelay) or 0.02)

            gifFrames[#gifFrames + 1] = {
                Index = #gifFrames + 1,
                X = frameX,
                Y = frameY,
                Width = frameWidth,
                Height = frameHeight,
                Interlaced = bit32.band(imagePacked, 64) ~= 0,
                ColorTable = frameColorTable,
                ColorCount = localColorCount > 0 and localColorCount or globalColorCount,
                CompressedData = compressedFrameData,
                LzwMinimumCodeSize = lzwMinimumCodeSize,
                Duration = frameDelaySeconds,
                Disposal = gifGraphicControl.Disposal,
                Transparent = gifGraphicControl.Transparent,
                TransparentIndex = gifGraphicControl.TransparentIndex,
                CompressedSize = #compressedFrameData
            }

            gifGraphicControl = {
                Delay = 0,
                Disposal = 0,
                Transparent = false,
                TransparentIndex = nil
            }
        elseif blockIntroducer == 0 then
            -- Some encoders insert harmless zero padding between blocks.
        else
            return nil, "GIF contains an unknown block marker at byte " .. tostring(gifPosition - 1) .. "."
        end
    end

    if #gifFrames == 0 then
        return nil, "The GIF did not contain any image frames."
    end

    return {
        Width = gifCanvasWidth,
        Height = gifCanvasHeight,
        Frames = gifFrames,
        FrameCount = #gifFrames,
        LoopExtensionFound = gifLoopExtensionFound,
        LoopCount = gifLoopCount,
        TotalPixels = gifTotalPixels,
        BackgroundPixel = globalColorTable and globalColorTable[gifBackgroundIndex] or string.char(0, 0, 0, 0),
        InitialTransparent = gifFrames[1].Transparent
    }
end

local function assetBridgeGifEncodeIndexedFramePNG(frameMetadata, decodedFramePixels, sourceRowOffsets, yieldEveryRows, useFastCompression)
    local frameWidth = frameMetadata.Width
    local frameHeight = frameMetadata.Height
    local frameColorCount = tonumber(frameMetadata.ColorCount) or 0
    local frameColorTable = frameMetadata.ColorTable
    if frameColorCount < 1 or frameColorCount > 256 then
        return nil, "GIF frame has an invalid palette size."
    end

    local paletteParts = table.create(frameColorCount)
    for paletteIndex = 0, frameColorCount - 1 do
        local palettePixel = frameColorTable[paletteIndex]
        if type(palettePixel) ~= "string" or #palettePixel < 3 then
            return nil, "GIF frame references an incomplete palette entry."
        end
        paletteParts[paletteIndex + 1] = string.sub(palettePixel, 1, 3)
    end

    local transparencyChunk = ""
    local transparentIndex = frameMetadata.TransparentIndex
    if transparentIndex ~= nil then
        if transparentIndex < 0 or transparentIndex >= frameColorCount then
            return nil, "GIF frame transparency index is outside its color table."
        end
        local transparencyParts = table.create(transparentIndex + 1)
        for paletteIndex = 0, transparentIndex do
            transparencyParts[paletteIndex + 1] = paletteIndex == transparentIndex and "\0" or "\255"
        end
        local transparencyData = table.concat(transparencyParts)
        local createdTransparencyChunk, transparencyError = assetBridgeGifCreatePNGChunk("tRNS", transparencyData, nil)
        if not createdTransparencyChunk then
            return nil, transparencyError
        end
        transparencyChunk = createdTransparencyChunk
    end

    local rawScanlines = table.create(frameHeight)
    local nextYieldRow = yieldEveryRows and yieldEveryRows > 0 and yieldEveryRows or nil
    for frameY = 1, frameHeight do
        local sourceRowStart
        if sourceRowOffsets then
            sourceRowStart = sourceRowOffsets[frameY]
            if not sourceRowStart then
                return nil, "GIF interlace row mapping is incomplete."
            end
        else
            sourceRowStart = (frameY - 1) * frameWidth + 1
        end

        local sourceRowEnd = sourceRowStart + frameWidth - 1
        rawScanlines[frameY] = "\0" .. string.sub(decodedFramePixels, sourceRowStart, sourceRowEnd)
        if nextYieldRow and frameY >= nextYieldRow then
            task.wait()
            nextYieldRow = nextYieldRow + yieldEveryRows
        end
    end

    local rawImageBytes = table.concat(rawScanlines)
    local yieldEveryBytes = yieldEveryRows and yieldEveryRows > 0 and math.max(4096, yieldEveryRows * frameWidth) or nil
    local compressedImageBytes = assetBridgeGifEncodeZlib(rawImageBytes, yieldEveryBytes, useFastCompression)
    local pngHeaderData = assetBridgeGifPackUInt32BE(frameWidth)
        .. assetBridgeGifPackUInt32BE(frameHeight)
        .. string.char(8, 3, 0, 0, 0)

    local headerChunk, headerError = assetBridgeGifCreatePNGChunk("IHDR", pngHeaderData, nil)
    if not headerChunk then
        return nil, headerError
    end
    local paletteChunk, paletteError = assetBridgeGifCreatePNGChunk("PLTE", table.concat(paletteParts), nil)
    if not paletteChunk then
        return nil, paletteError
    end
    local imageChunk, imageError = assetBridgeGifCreatePNGChunk("IDAT", compressedImageBytes, yieldEveryBytes)
    if not imageChunk then
        return nil, imageError
    end
    local endChunk, endError = assetBridgeGifCreatePNGChunk("IEND", "", nil)
    if not endChunk then
        return nil, endError
    end

    return "\137PNG\r\n\26\n" .. headerChunk .. paletteChunk .. transparencyChunk .. imageChunk .. endChunk, "indexed"
end

local function assetBridgeGifBuildPatchFrame(gifDecoder, frameIndex)
    if gifDecoder._destroyed then
        return nil, "This GIF decoder has been destroyed."
    end

    local frameMetadata = gifDecoder.Frames[frameIndex]
    if not frameMetadata then
        return nil, "GIF frame " .. tostring(frameIndex) .. " does not exist."
    end

    local decodeStartedAt = os.clock()
    local animationHash = assetBridgeHashString(gifDecoder.Url)
    local frameFilePath = assetBridgeCacheDirectories.GIF .. "/" .. animationHash .. "_Patch_v3_" .. string.format("%04d", frameIndex) .. ".png"
    local useExistingFile = not gifDecoder._refresh and assetBridgeFileExists(frameFilePath)
    local frameOutputSize = 0
    local outputMode = "cached"
    local lzwDecodeTime = 0
    local pngEncodeTime = 0
    local fileWriteTime = 0

    if not useExistingFile then
        local lzwDecodeStartedAt = os.clock()
        local decodedFramePixels, frameDecodeError = assetBridgeGifDecodeLZW(
            frameMetadata.CompressedData,
            frameMetadata.LzwMinimumCodeSize,
            frameMetadata.Width * frameMetadata.Height,
            gifDecoder._yieldEveryCodes
        )
        if not decodedFramePixels then
            return nil, frameDecodeError
        end
        lzwDecodeTime = os.clock() - lzwDecodeStartedAt

        local frameSourceRowOffsets = nil
        if frameMetadata.Interlaced then
            frameSourceRowOffsets = table.create(frameMetadata.Height)
            local frameSourceRow = 0
            local interlacePasses = {
                {Start = 0, Step = 8},
                {Start = 4, Step = 8},
                {Start = 2, Step = 4},
                {Start = 1, Step = 2}
            }
            for _, interlacePass in ipairs(interlacePasses) do
                local destinationY = interlacePass.Start
                while destinationY < frameMetadata.Height do
                    frameSourceRowOffsets[destinationY + 1] = frameSourceRow * frameMetadata.Width + 1
                    frameSourceRow = frameSourceRow + 1
                    destinationY = destinationY + interlacePass.Step
                end
            end
        end

        if gifDecoder._destroyed or gifDecoder._sessionGeneration ~= assetBridgeSessionGeneration then
            return nil, "AssetBridge was closed while GIF frames were being built."
        end

        local pngEncodeStartedAt = os.clock()
        local pngFrameBytes, pngFrameModeOrError = assetBridgeGifEncodeIndexedFramePNG(
            frameMetadata,
            decodedFramePixels,
            frameSourceRowOffsets,
            gifDecoder._yieldEveryRows,
            gifDecoder._fastCompression
        )
        if not pngFrameBytes then
            return nil, pngFrameModeOrError
        end
        pngEncodeTime = os.clock() - pngEncodeStartedAt

        if gifDecoder._destroyed or gifDecoder._sessionGeneration ~= assetBridgeSessionGeneration then
            return nil, "AssetBridge was closed while GIF frames were being built."
        end

        local gifFolderSuccess, gifFolderError = assetBridgeEnsureFolder(assetBridgeCacheDirectories.GIF)
        if not gifFolderSuccess then
            return nil, gifFolderError
        end
        if type(assetBridgeWriteFileFunction) ~= "function" then
            return nil, "GIF frame generation requires executor writefile()."
        end

        local fileWriteStartedAt = os.clock()
        local writeSuccess, writeError = pcall(assetBridgeWriteFileFunction, frameFilePath, pngFrameBytes)
        fileWriteTime = os.clock() - fileWriteStartedAt
        if not writeSuccess then
            return nil, "Could not write decoded GIF frame " .. tostring(frameIndex) .. ": " .. tostring(writeError)
        end

        frameOutputSize = #pngFrameBytes
        outputMode = pngFrameModeOrError or "indexed"
        gifDecoder.TotalOutputBytes = gifDecoder.TotalOutputBytes + frameOutputSize
        if outputMode == "indexed" then
            gifDecoder.Stats.IndexedFrames = gifDecoder.Stats.IndexedFrames + 1
        else
            gifDecoder.Stats.RgbaFrames = gifDecoder.Stats.RgbaFrames + 1
        end
        gifDecoder.Stats.TotalLzwDecodeTime = (gifDecoder.Stats.TotalLzwDecodeTime or 0) + lzwDecodeTime
        gifDecoder.Stats.TotalPngEncodeTime = (gifDecoder.Stats.TotalPngEncodeTime or 0) + pngEncodeTime
        gifDecoder.Stats.TotalFileWriteTime = (gifDecoder.Stats.TotalFileWriteTime or 0) + fileWriteTime
    else
        gifDecoder.Stats.CachedFrames = (gifDecoder.Stats.CachedFrames or 0) + 1
    end

    if gifDecoder._destroyed or gifDecoder._sessionGeneration ~= assetBridgeSessionGeneration then
        return nil, "AssetBridge was closed while GIF frames were being built."
    end

    gifDecoder.Stats.TotalPatchPixels = (gifDecoder.Stats.TotalPatchPixels or 0) + frameMetadata.Width * frameMetadata.Height
    assetBridgeTrackedFiles[frameFilePath] = true
    local frameResult = {
        Index = frameIndex,
        FilePath = frameFilePath,
        FileReady = true,
        Duration = frameMetadata.Duration,
        Size = frameOutputSize,
        OutputMode = outputMode,
        CompressedSize = frameMetadata.CompressedSize,
        DecodeTime = os.clock() - decodeStartedAt,
        LzwDecodeTime = lzwDecodeTime,
        PngEncodeTime = pngEncodeTime,
        FileWriteTime = fileWriteTime,
        X = frameMetadata.X,
        Y = frameMetadata.Y,
        Width = frameMetadata.Width,
        Height = frameMetadata.Height,
        CanvasWidth = gifDecoder.Width,
        CanvasHeight = gifDecoder.Height,
        SourceWidth = frameMetadata.Width,
        SourceHeight = frameMetadata.Height,
        Disposal = frameMetadata.Disposal,
        Transparent = frameMetadata.Transparent,
        TransparentIndex = frameMetadata.TransparentIndex,
        Interlaced = frameMetadata.Interlaced
    }

    gifDecoder.DecodedFrames[frameIndex] = frameResult
    while gifDecoder.DecodedFrames[gifDecoder.DecodedFrameCount + 1] do
        gifDecoder.DecodedFrameCount = gifDecoder.DecodedFrameCount + 1
    end
    gifDecoder.CurrentFrame = math.max(gifDecoder.CurrentFrame, frameIndex)
    return frameResult
end

local function assetBridgeGifIncrementalDecodeFrame(gifDecoder)
    local nextFrameIndex = gifDecoder.DecodedFrameCount + 1
    if nextFrameIndex > gifDecoder.FrameCount then
        return nil, "All GIF frames have already been decoded."
    end
    return assetBridgeGifBuildPatchFrame(gifDecoder, nextFrameIndex)
end

function assetBridgeGifDecoderMethods:DecodeNextFrame()
    local decodedFrame, decodeError = assetBridgeGifIncrementalDecodeFrame(self)
    if decodedFrame then
        local frameMetadata = self.Frames[decodedFrame.Index]
        if frameMetadata then
            frameMetadata.CompressedData = nil
            frameMetadata.ColorTable = nil
        end
        self._hasReleasedCompressedFrames = true
    end
    return decodedFrame, decodeError
end

function assetBridgeGifDecoderMethods:DecodeNextFramesParallel(frameCount, onFrameDecoded, onDecodeProgress)
    if self._destroyed then
        return nil, "This GIF decoder has been destroyed."
    end

    frameCount = math.max(1, math.floor(tonumber(frameCount) or 1))
    local firstFrameIndex = self.DecodedFrameCount + 1
    local totalFrameCount = math.min(frameCount, self.FrameCount - self.DecodedFrameCount)
    if totalFrameCount <= 0 then
        return nil, "All GIF frames have already been decoded."
    end

    local lastFrameIndex = firstFrameIndex + totalFrameCount - 1
    local maximumParallelWorkers = math.max(1, math.min(totalFrameCount, math.floor(tonumber(self._parallelWorkers) or 4)))
    local nextFrameToBuild = firstFrameIndex
    local completedFrameCount = 0
    local finishedWorkerCount = 0
    local stopWorkers = false
    local firstBuildFailure = nil

    local function runGifFrameWorker()
        task.wait()
        while not stopWorkers and not self._destroyed do
            local assignedFrameIndex = nextFrameToBuild
            if assignedFrameIndex > lastFrameIndex then
                break
            end
            nextFrameToBuild = assignedFrameIndex + 1

            local frameBuildStartedAt = os.clock()
            local buildCallSuccess, builtFrame, buildError = pcall(
                assetBridgeGifBuildPatchFrame,
                self,
                assignedFrameIndex
            )
            if not buildCallSuccess then
                buildError = builtFrame
                builtFrame = nil
            end

            if self._destroyed or self._sessionGeneration ~= assetBridgeSessionGeneration then
                stopWorkers = true
                break
            end

            if builtFrame then
                builtFrame.WorkerTime = os.clock() - frameBuildStartedAt
            elseif not firstBuildFailure then
                firstBuildFailure = string.format(
                    "Frame %d failed during LZW decoding or PNG generation: %s",
                    assignedFrameIndex,
                    tostring(buildError or "Unknown decoder error")
                )
            end

            completedFrameCount = completedFrameCount + 1
            if type(onDecodeProgress) == "function" then
                pcall(onDecodeProgress, completedFrameCount, totalFrameCount, assignedFrameIndex, builtFrame ~= nil, buildError)
            end
            if builtFrame and type(onFrameDecoded) == "function" then
                pcall(onFrameDecoded, builtFrame, completedFrameCount, totalFrameCount)
            end

            if firstBuildFailure then
                stopWorkers = true
            end
        end

        finishedWorkerCount = finishedWorkerCount + 1
    end

    for workerIndex = 1, maximumParallelWorkers do
        task.spawn(runGifFrameWorker)
    end

    while finishedWorkerCount < maximumParallelWorkers do
        if self._destroyed or self._sessionGeneration ~= assetBridgeSessionGeneration then
            stopWorkers = true
        end
        task.wait()
    end

    if self._destroyed then
        return nil, "This GIF decoder was destroyed while frames were being built."
    end
    if firstBuildFailure then
        return nil, firstBuildFailure
    end

    local decodedFrames = table.create(totalFrameCount)
    for frameIndex = firstFrameIndex, lastFrameIndex do
        local decodedFrame = self.DecodedFrames[frameIndex]
        if not decodedFrame then
            return nil, "GIF frame " .. tostring(frameIndex) .. " was not generated."
        end
        decodedFrames[#decodedFrames + 1] = decodedFrame
    end

    for frameIndex = firstFrameIndex, lastFrameIndex do
        local frameMetadata = self.Frames[frameIndex]
        if frameMetadata then
            frameMetadata.CompressedData = nil
            frameMetadata.ColorTable = nil
        end
    end
    self._hasReleasedCompressedFrames = true
    return decodedFrames
end

function assetBridgeGifDecoderMethods:GetDecodedFrame(frameIndex)
    frameIndex = math.floor(tonumber(frameIndex) or 0)
    return self.DecodedFrames[frameIndex]
end

function assetBridgeGifDecoderMethods:Reset()
    if self._destroyed then
        return false, "This GIF decoder has been destroyed."
    end
    if self._hasReleasedCompressedFrames then
        return false, "This GIF decoder has already released its compressed frame data to save memory. Open the GIF again to rebuild it."
    end
    self.DecodedFrames = {}
    self.DecodedFrameCount = 0
    self.CurrentFrame = 0
    self.TotalOutputBytes = 0
    self.Stats.IndexedFrames = 0
    self.Stats.RgbaFrames = 0
    self.Stats.ReusedFrames = 0
    self.Stats.CachedFrames = 0
    self.Stats.TotalPatchPixels = 0
    self.Stats.TotalLzwDecodeTime = 0
    self.Stats.TotalPngEncodeTime = 0
    self.Stats.TotalFileWriteTime = 0
    return true
end

function assetBridgeGifDecoderMethods:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    self.DecodedFrames = {}
    self.Frames = {}
    self._gifBytes = nil
    assetBridgeActiveResources[self] = nil
end

local assetBridgeGifDecoderMetatable = {
    __index = function(gifDecoder, propertyName)
        local decoderMethod = assetBridgeGifDecoderMethods[propertyName]
        if decoderMethod then
            return decoderMethod
        end
        return rawget(gifDecoder, propertyName)
    end
}

local function assetBridgeCreateIncrementalGifDecoder(gifDownload, gifScanned, gifOptions)
    if type(assetBridgeWriteFileFunction) ~= "function" then
        return nil, "GIF frame generation requires executor writefile()."
    end
    local transparentPixel = string.char(0, 0, 0, 0)
    local backgroundPixel = gifScanned.BackgroundPixel or transparentPixel
    local decoder = setmetatable({
        Url = gifDownload.Url,
        Width = gifScanned.Width,
        Height = gifScanned.Height,
        FrameCount = gifScanned.FrameCount,
        Frames = gifScanned.Frames,
        DecodedFrames = {},
        DecodedFrameCount = 0,
        CurrentFrame = 0,
        LoopExtensionFound = gifScanned.LoopExtensionFound,
        LoopCount = gifScanned.LoopCount,
        TotalPixels = gifScanned.TotalPixels,
        TotalOutputBytes = 0,
        Stats = {
            IndexedFrames = 0,
            RgbaFrames = 0,
            ReusedFrames = 0,
            CachedFrames = 0,
            TotalPatchPixels = 0,
            TotalLzwDecodeTime = 0,
            TotalPngEncodeTime = 0,
            TotalFileWriteTime = 0
        },
        Format = "gif",
        Cached = gifDownload.Cached,
        _backgroundPixel = backgroundPixel,
        _transparentPixel = transparentPixel,
        _initialTransparent = gifScanned.InitialTransparent,
        _yieldEveryRows = math.max(0, math.floor(tonumber(gifOptions.YieldEveryRows) or 24)),
        _yieldEveryCodes = math.max(0, math.floor(tonumber(gifOptions.YieldEveryCodes) or 8192)),
        _parallelWorkers = math.clamp(math.floor(tonumber(gifOptions.ParallelWorkers) or 4), 1, 8),
        _fastCompression = gifOptions.FastCompression ~= false,
        _refresh = gifOptions.Refresh == true or gifOptions.RefreshFrames == true,
        _sessionGeneration = assetBridgeSessionGeneration,
        _destroyed = false,
    }, assetBridgeGifDecoderMetatable)

    local totalDuration = 0
    local totalCompressedBytes = 0
    for _, frameMetadata in ipairs(gifScanned.Frames) do
        totalDuration = totalDuration + frameMetadata.Duration
        totalCompressedBytes = totalCompressedBytes + frameMetadata.CompressedSize
    end
    decoder.Duration = totalDuration
    decoder.CompressedSize = totalCompressedBytes
    assetBridgeActiveResources[decoder] = true

    return decoder
end

local assetBridgeGifEnsureFrameBuilt
local assetBridgeGifPlayerMethods = {}

local function assetBridgeGifPreloadFrame(gifAnimation, gifFrameIndex)
    if gifAnimation._destroyed then
        return
    end
    if gifAnimation._preloading then
        gifAnimation._preloadRequestedFrame = gifFrameIndex
        return
    end

    local gifFrameData = gifAnimation.Frames[gifFrameIndex]
    if not gifFrameData or rawget(gifFrameData, "ImageId") or rawget(gifFrameData, "_AssetLoading") then
        return
    end

    local preloadEndFrame = math.min(
        gifAnimation.FrameCount,
        gifFrameIndex + math.max(1, gifAnimation._preloadFrameCount or 2) - 1
    )
    for preloadFrameIndex = gifFrameIndex, preloadEndFrame do
        local preloadFrameData = gifAnimation.Frames[preloadFrameIndex]
        if preloadFrameData and not rawget(preloadFrameData, "ImageId") then
            rawset(preloadFrameData, "_AssetLoading", true)
        end
    end

    gifAnimation._preloading = true
    task.spawn(function()
        local buildSuccess, buildError = assetBridgeGifEnsureFrameBuilt(gifAnimation, preloadEndFrame)
        if buildSuccess and not gifAnimation._destroyed then
            for preloadFrameIndex = gifFrameIndex, preloadEndFrame do
                local preloadFrameData = gifAnimation.Frames[preloadFrameIndex]
                if preloadFrameData and not rawget(preloadFrameData, "ImageId") then
                    local preloadImageId, preloadAssetError = assetBridgeGetCustomAssetId(preloadFrameData.FilePath)
                    if preloadImageId then
                        rawset(preloadFrameData, "ImageId", preloadImageId)
                    else
                        rawset(preloadFrameData, "AssetError", preloadAssetError)
                    end
                end
                if preloadFrameData then
                    rawset(preloadFrameData, "_AssetLoading", nil)
                end
            end
        elseif not gifAnimation._destroyed then
            for preloadFrameIndex = gifFrameIndex, preloadEndFrame do
                local preloadFrameData = gifAnimation.Frames[preloadFrameIndex]
                if preloadFrameData then
                    rawset(preloadFrameData, "AssetError", buildError)
                    rawset(preloadFrameData, "_AssetLoading", nil)
                end
            end
        end

        gifAnimation._preloading = false
        local requestedPreloadFrame = gifAnimation._preloadRequestedFrame
        gifAnimation._preloadRequestedFrame = nil
        if requestedPreloadFrame and requestedPreloadFrame <= gifAnimation.FrameCount and not gifAnimation._destroyed then
            assetBridgeGifPreloadFrame(gifAnimation, requestedPreloadFrame)
        end
    end)
end

local function assetBridgeGifCreateLayerPiece(gifPlayer, gifLayer, gifPiece)
    local gifTarget = gifPlayer._target
    if not gifTarget or not gifTarget.Parent then
        return nil, "The GIF player's target is no longer parented."
    end

    local gifCanvasWidth = math.max(1, gifPlayer._animation.Width)
    local gifCanvasHeight = math.max(1, gifPlayer._animation.Height)
    local gifPieceInstance = assetBridgeInstanceNew(gifLayer.Kind == "image" and "ImageLabel" or "Frame")
    gifPieceInstance.Name = "AssetBridgeGifPatch"
    gifPieceInstance.AnchorPoint = Vector2.zero
    gifPieceInstance.Position = UDim2.fromScale(gifPiece.X / gifCanvasWidth, gifPiece.Y / gifCanvasHeight)
    gifPieceInstance.Size = UDim2.fromScale(gifPiece.Width / gifCanvasWidth, gifPiece.Height / gifCanvasHeight)
    gifPieceInstance.BorderSizePixel = 0
    gifPieceInstance.ZIndex = gifLayer.Container.ZIndex + 1

    if gifLayer.Kind == "image" then
        gifPieceInstance.BackgroundTransparency = 1
        gifPieceInstance.Image = gifLayer.ImageId
        gifPieceInstance.ImageColor3 = Color3.new(1, 1, 1)
        gifPieceInstance.ImageTransparency = 0
        gifPieceInstance.ScaleType = Enum.ScaleType.Stretch
        gifPieceInstance.ImageRectOffset = Vector2.new(gifPiece.SourceX or 0, gifPiece.SourceY or 0)
        gifPieceInstance.ImageRectSize = Vector2.new(gifPiece.Width, gifPiece.Height)
    else
        gifPieceInstance.BackgroundColor3 = gifLayer.BackgroundColor
        gifPieceInstance.BackgroundTransparency = gifLayer.BackgroundTransparency
    end

    gifPieceInstance.Parent = gifLayer.Container
    return gifPieceInstance
end

local function assetBridgeGifRebuildPlayerLayer(gifPlayer, gifLayer)
    if not gifLayer.Container or not gifLayer.Container.Parent then
        return false, "The GIF layer container no longer exists."
    end

    for _, gifChild in ipairs(gifLayer.Container:GetChildren()) do
        gifChild:Destroy()
    end

    for _, gifPiece in ipairs(gifLayer.Pieces) do
        local pieceSuccess, pieceResult = pcall(assetBridgeGifCreateLayerPiece, gifPlayer, gifLayer, gifPiece)
        if not pieceSuccess then
            return false, tostring(pieceResult)
        end
        if not pieceResult then
            return false, "Could not create a GIF image layer piece."
        end
    end
    return true
end

local function assetBridgeGifAddPlayerLayer(gifPlayer, layerKind, pieces, layerProperties)
    local gifTarget = gifPlayer._target
    if not gifTarget or not gifTarget.Parent then
        return nil, "The GIF player's target is no longer parented."
    end

    local gifLayerContainer = assetBridgeInstanceNew("Frame")
    gifLayerContainer.Name = "AssetBridgeGifLayer"
    gifLayerContainer.AnchorPoint = Vector2.zero
    local viewportWidthScale = 1
    local viewportHeightScale = 1
    local viewportXScale = 0
    local viewportYScale = 0
    if gifTarget.ScaleType == Enum.ScaleType.Fit then
        local targetAbsoluteSize = gifTarget.AbsoluteSize
        if targetAbsoluteSize.X > 0 and targetAbsoluteSize.Y > 0 then
            local targetAspectRatio = targetAbsoluteSize.X / targetAbsoluteSize.Y
            local animationAspectRatio = gifPlayer._animation.Width / gifPlayer._animation.Height
            if targetAspectRatio > animationAspectRatio then
                viewportWidthScale = animationAspectRatio / targetAspectRatio
                viewportXScale = (1 - viewportWidthScale) / 2
            else
                viewportHeightScale = targetAspectRatio / animationAspectRatio
                viewportYScale = (1 - viewportHeightScale) / 2
            end
        end
    end
    gifLayerContainer.Position = UDim2.fromScale(viewportXScale, viewportYScale)
    gifLayerContainer.Size = UDim2.fromScale(viewportWidthScale, viewportHeightScale)
    gifLayerContainer.BackgroundTransparency = 1
    gifLayerContainer.BorderSizePixel = 0
    gifLayerContainer.ClipsDescendants = true
    local gifLayerZIndex = gifPlayer._nextLayerZIndex or (gifTarget.ZIndex + 1)
    gifPlayer._nextLayerZIndex = gifLayerZIndex + 2
    gifLayerContainer.ZIndex = gifLayerZIndex
    gifLayerContainer.Parent = gifTarget

    local gifLayer = {
        Kind = layerKind,
        Container = gifLayerContainer,
        Pieces = pieces,
        ImageId = layerProperties and layerProperties.ImageId,
        BackgroundColor = layerProperties and layerProperties.BackgroundColor,
        BackgroundTransparency = layerProperties and layerProperties.BackgroundTransparency or 0
    }
    table.insert(gifPlayer._layers, gifLayer)

    local layerBuildSuccess, layerBuildError = assetBridgeGifRebuildPlayerLayer(gifPlayer, gifLayer)
    if not layerBuildSuccess then
        gifLayerContainer:Destroy()
        table.remove(gifPlayer._layers, #gifPlayer._layers)
        return nil, layerBuildError
    end
    return gifLayer
end

local function assetBridgeGifRemovePlayerLayer(gifPlayer, gifLayer)
    if not gifLayer then
        return
    end
    if gifLayer.Container then
        pcall(function()
            gifLayer.Container:Destroy()
        end)
        gifLayer.Container = nil
    end
    for layerIndex = #gifPlayer._layers, 1, -1 do
        if gifPlayer._layers[layerIndex] == gifLayer then
            table.remove(gifPlayer._layers, layerIndex)
            break
        end
    end
end

local function assetBridgeGifSplitPieceAroundClearRect(gifPiece, clearX, clearY, clearWidth, clearHeight)
    local pieceLeft = gifPiece.X
    local pieceTop = gifPiece.Y
    local pieceRight = pieceLeft + gifPiece.Width
    local pieceBottom = pieceTop + gifPiece.Height
    local clearLeft = clearX
    local clearTop = clearY
    local clearRight = clearX + clearWidth
    local clearBottom = clearY + clearHeight

    local intersectionLeft = math.max(pieceLeft, clearLeft)
    local intersectionTop = math.max(pieceTop, clearTop)
    local intersectionRight = math.min(pieceRight, clearRight)
    local intersectionBottom = math.min(pieceBottom, clearBottom)

    if intersectionLeft >= intersectionRight or intersectionTop >= intersectionBottom then
        return {gifPiece}
    end

    local retainedPieces = {}
    local function appendPiece(pieceX, pieceY, pieceWidth, pieceHeight)
        if pieceWidth <= 0 or pieceHeight <= 0 then
            return
        end
        retainedPieces[#retainedPieces + 1] = {
            X = pieceX,
            Y = pieceY,
            Width = pieceWidth,
            Height = pieceHeight,
            SourceX = (gifPiece.SourceX or 0) + pieceX - pieceLeft,
            SourceY = (gifPiece.SourceY or 0) + pieceY - pieceTop
        }
    end

    appendPiece(pieceLeft, pieceTop, gifPiece.Width, intersectionTop - pieceTop)
    appendPiece(pieceLeft, intersectionBottom, gifPiece.Width, pieceBottom - intersectionBottom)
    appendPiece(pieceLeft, intersectionTop, intersectionLeft - pieceLeft, intersectionBottom - intersectionTop)
    appendPiece(intersectionRight, intersectionTop, pieceRight - intersectionRight, intersectionBottom - intersectionTop)
    return retainedPieces
end

local function assetBridgeGifClipPlayerLayers(gifPlayer, clearX, clearY, clearWidth, clearHeight)
    for layerIndex = #gifPlayer._layers, 1, -1 do
        local gifLayer = gifPlayer._layers[layerIndex]
        local replacementPieces = {}
        for _, gifPiece in ipairs(gifLayer.Pieces) do
            local splitPieces = assetBridgeGifSplitPieceAroundClearRect(gifPiece, clearX, clearY, clearWidth, clearHeight)
            for _, retainedPiece in ipairs(splitPieces) do
                replacementPieces[#replacementPieces + 1] = retainedPiece
            end
        end
        gifLayer.Pieces = replacementPieces

        if #replacementPieces == 0 then
            assetBridgeGifRemovePlayerLayer(gifPlayer, gifLayer)
        else
            local rebuildSuccess, rebuildError = assetBridgeGifRebuildPlayerLayer(gifPlayer, gifLayer)
            if not rebuildSuccess then
                return false, rebuildError
            end
        end
    end
    return true
end

local function assetBridgeGifGetBackgroundProperties(gifAnimation)
    local backgroundPixel = gifAnimation._backgroundPixel or string.char(0, 0, 0, 0)
    local red = string.byte(backgroundPixel, 1) or 0
    local green = string.byte(backgroundPixel, 2) or 0
    local blue = string.byte(backgroundPixel, 3) or 0
    local alpha = string.byte(backgroundPixel, 4) or 255
    local backgroundTransparency = gifAnimation._initialTransparent and 1 or (1 - alpha / 255)
    return Color3.fromRGB(red, green, blue), backgroundTransparency
end

local function assetBridgeGifResetPlayerLayers(gifPlayer)
    for layerIndex = #gifPlayer._layers, 1, -1 do
        assetBridgeGifRemovePlayerLayer(gifPlayer, gifPlayer._layers[layerIndex])
    end
    gifPlayer._previousFrame = nil
    gifPlayer._displayedThrough = 0
    gifPlayer._nextLayerZIndex = gifPlayer._target.ZIndex + 1

    if not gifPlayer._animation._initialTransparent then
        local backgroundColor, backgroundTransparency = assetBridgeGifGetBackgroundProperties(gifPlayer._animation)
        if backgroundTransparency < 1 then
            local backgroundLayer, backgroundError = assetBridgeGifAddPlayerLayer(
                gifPlayer,
                "background",
                {{X = 0, Y = 0, Width = gifPlayer._animation.Width, Height = gifPlayer._animation.Height}},
                {BackgroundColor = backgroundColor, BackgroundTransparency = backgroundTransparency}
            )
            if not backgroundLayer then
                return false, backgroundError
            end
        end
    end
    return true
end

local function assetBridgeGifApplyPreviousFrameDisposal(gifPlayer)
    local previousFrame = gifPlayer._previousFrame
    if not previousFrame then
        return true
    end

    if previousFrame.Disposal == 2 then
        local clipSuccess, clipError = assetBridgeGifClipPlayerLayers(
            gifPlayer,
            previousFrame.X,
            previousFrame.Y,
            previousFrame.Width,
            previousFrame.Height
        )
        if not clipSuccess then
            return false, clipError
        end

        local backgroundColor, backgroundTransparency = assetBridgeGifGetBackgroundProperties(gifPlayer._animation)
        if backgroundTransparency < 1 then
            local backgroundLayer, backgroundError = assetBridgeGifAddPlayerLayer(
                gifPlayer,
                "background",
                {{X = previousFrame.X, Y = previousFrame.Y, Width = previousFrame.Width, Height = previousFrame.Height}},
                {BackgroundColor = backgroundColor, BackgroundTransparency = backgroundTransparency}
            )
            if not backgroundLayer then
                return false, backgroundError
            end
        end
    elseif previousFrame.Disposal == 3 then
        assetBridgeGifRemovePlayerLayer(gifPlayer, previousFrame.Layer)
    end

    gifPlayer._previousFrame = nil
    return true
end

local function assetBridgeGifGetPlayerFrameImageId(gifAnimation, gifFrameIndex)
    local gifFrameData = gifAnimation.Frames[gifFrameIndex]
    if not gifFrameData then
        return nil, "GIF frame " .. tostring(gifFrameIndex) .. " does not exist."
    end

    while rawget(gifFrameData, "_AssetLoading") and not gifAnimation._destroyed do
        task.wait()
    end
    if gifAnimation._destroyed then
        return nil, "This GIF animation has been destroyed."
    end
    if rawget(gifFrameData, "ImageId") then
        return rawget(gifFrameData, "ImageId")
    end

    local buildSuccess, buildError = assetBridgeGifEnsureFrameBuilt(gifAnimation, gifFrameIndex)
    if not buildSuccess then
        return nil, buildError
    end

    local gifFrameImageId, gifFrameAssetError = assetBridgeGetCustomAssetId(gifFrameData.FilePath)
    if not gifFrameImageId then
        rawset(gifFrameData, "AssetError", gifFrameAssetError)
        return nil, gifFrameAssetError
    end
    rawset(gifFrameData, "ImageId", gifFrameImageId)
    return gifFrameImageId
end

local function assetBridgeGifSetPlayerFrame(gifPlayer, gifFrameIndex)
    local gifAnimation = gifPlayer._animation
    if gifAnimation._destroyed then
        return false, "This GIF animation has been destroyed."
    end

    gifFrameIndex = math.floor(tonumber(gifFrameIndex) or 1)
    gifFrameIndex = math.clamp(gifFrameIndex, 1, gifAnimation.FrameCount)

    local buildSuccess, buildError = assetBridgeGifEnsureFrameBuilt(gifAnimation, gifFrameIndex)
    if not buildSuccess then
        return false, "Could not build GIF frame " .. tostring(gifFrameIndex) .. ": " .. tostring(buildError)
    end

    if gifFrameIndex <= (gifPlayer._displayedThrough or 0) then
        local resetSuccess, resetError = assetBridgeGifResetPlayerLayers(gifPlayer)
        if not resetSuccess then
            return false, resetError
        end
    elseif gifPlayer._displayedThrough == nil then
        local resetSuccess, resetError = assetBridgeGifResetPlayerLayers(gifPlayer)
        if not resetSuccess then
            return false, resetError
        end
    end

    for currentFrameIndex = (gifPlayer._displayedThrough or 0) + 1, gifFrameIndex do
        local currentFrameData = gifAnimation.Frames[currentFrameIndex]
        local frameImageId, frameAssetError = assetBridgeGifGetPlayerFrameImageId(gifAnimation, currentFrameIndex)
        if not frameImageId then
            return false, "Could not create local asset for GIF frame " .. tostring(currentFrameIndex) .. ": " .. tostring(frameAssetError)
        end

        local disposalSuccess, disposalError = assetBridgeGifApplyPreviousFrameDisposal(gifPlayer)
        if not disposalSuccess then
            return false, disposalError
        end

        local frameLayer, layerError = assetBridgeGifAddPlayerLayer(
            gifPlayer,
            "image",
            {{
                X = currentFrameData.X,
                Y = currentFrameData.Y,
                Width = currentFrameData.SourceWidth,
                Height = currentFrameData.SourceHeight,
                SourceX = 0,
                SourceY = 0
            }},
            {ImageId = frameImageId}
        )
        if not frameLayer then
            return false, layerError
        end

        gifPlayer._previousFrame = {
            X = currentFrameData.X,
            Y = currentFrameData.Y,
            Width = currentFrameData.SourceWidth,
            Height = currentFrameData.SourceHeight,
            Disposal = currentFrameData.Disposal,
            Layer = frameLayer
        }
        gifPlayer._displayedThrough = currentFrameIndex
    end

    gifPlayer.CurrentFrame = gifFrameIndex
    gifPlayer.CurrentTime = 0
    for precedingFrameIndex = 1, gifFrameIndex - 1 do
        gifPlayer.CurrentTime = gifPlayer.CurrentTime + gifAnimation.Frames[precedingFrameIndex].Duration
    end

    local nextFrameIndex = gifFrameIndex >= gifAnimation.FrameCount and 1 or gifFrameIndex + 1
    if gifAnimation.FrameCount > 1 then
        assetBridgeGifPreloadFrame(gifAnimation, nextFrameIndex)
    end

    return true
end

local function assetBridgeGifRunPlayer(gifPlayer, playbackToken)
    task.spawn(function()
        local gifAnimationData = gifPlayer._animation
        local gifTotalPlaythroughs = 0

        while gifPlayer._state ~= "destroyed" and gifPlayer._token == playbackToken do
            if gifPlayer._state == "paused" then
                task.wait(0.03)
            elseif gifPlayer._state == "playing" then
                local gifCurrentFrameData = gifAnimationData.Frames[gifPlayer.CurrentFrame]
                local gifRemainingFrameTime = gifCurrentFrameData.Duration
                local gifFrameStartAnimationTime = gifPlayer.CurrentTime

                while gifRemainingFrameTime > 0 and gifPlayer._token == playbackToken and gifPlayer._state ~= "destroyed" do
                    if gifPlayer._state == "paused" then
                        task.wait(0.03)
                    elseif gifPlayer._state == "playing" then
                        local gifCurrentPlaybackSpeed = math.max(0.05, tonumber(gifPlayer.PlaybackSpeed) or 1)
                        local gifRequestedWait = math.min(gifRemainingFrameTime / gifCurrentPlaybackSpeed, 0.03)
                        local gifActualWait = task.wait(gifRequestedWait)
                        gifRemainingFrameTime = math.max(0, gifRemainingFrameTime - (gifActualWait * gifCurrentPlaybackSpeed))
                        gifPlayer.CurrentTime = gifFrameStartAnimationTime + gifCurrentFrameData.Duration - gifRemainingFrameTime
                    else
                        break
                    end
                end

                if gifPlayer._token == playbackToken and gifPlayer._state == "playing" then
                    if gifPlayer.CurrentFrame >= gifAnimationData.FrameCount then
                        gifTotalPlaythroughs = gifTotalPlaythroughs + 1

                        if gifTotalPlaythroughs >= gifPlayer._maximumPlaythroughs then
                            gifPlayer._state = "ended"
                            gifPlayer.IsPlaying = false
                            gifPlayer.IsPaused = false
                            gifPlayer.EndedEvent:Fire()
                            break
                        end

                        local resetFrameSuccess, resetFrameError = assetBridgeGifSetPlayerFrame(gifPlayer, 1)
                        if not resetFrameSuccess then
                            gifPlayer._state = "error"
                            gifPlayer._lastError = resetFrameError
                            gifPlayer.IsPlaying = false
                            gifPlayer.IsPaused = false
                            break
                        end
                    else
                        local nextFrameSuccess, nextFrameError = assetBridgeGifSetPlayerFrame(gifPlayer, gifPlayer.CurrentFrame + 1)
                        if not nextFrameSuccess then
                            gifPlayer._state = "error"
                            gifPlayer._lastError = nextFrameError
                            gifPlayer.IsPlaying = false
                            gifPlayer.IsPaused = false
                            break
                        end
                    end
                end
            else
                break
            end
        end
    end)
end

function assetBridgeGifPlayerMethods:Play()
    local previousPlayerState = self._state

    if previousPlayerState == "destroyed" then
        return false, "This GIF player has been destroyed."
    end

    if previousPlayerState == "paused" then
        return self:Resume()
    end

    if previousPlayerState == "playing" then
        return true
    end

    self._token = self._token + 1
    self._state = "playing"
    self.IsPlaying = true
    self.IsPaused = false

    if previousPlayerState == "ended" or self.CurrentFrame >= self._animation.FrameCount then
        local resetFrameSuccess, resetFrameError = assetBridgeGifSetPlayerFrame(self, 1)
        if not resetFrameSuccess then
            self._state = "stopped"
            self.IsPlaying = false
            return false, resetFrameError
        end
    end

    assetBridgeGifRunPlayer(self, self._token)
    return true
end

function assetBridgeGifPlayerMethods:Pause()
    if self._state == "destroyed" then
        return false, "This GIF player has been destroyed."
    end

    if self._state == "playing" then
        self._state = "paused"
        self.IsPlaying = false
        self.IsPaused = true
    end

    return true
end

function assetBridgeGifPlayerMethods:Resume()
    if self._state == "destroyed" then
        return false, "This GIF player has been destroyed."
    end

    if self._state == "paused" then
        self._state = "playing"
        self.IsPlaying = true
        self.IsPaused = false
    elseif self._state == "stopped" or self._state == "ended" then
        return self:Play()
    end

    return true
end

function assetBridgeGifPlayerMethods:Stop()
    if self._state == "destroyed" then
        return false, "This GIF player has been destroyed."
    end

    self._token = self._token + 1
    self._state = "stopped"
    self.IsPlaying = false
    self.IsPaused = false
    return assetBridgeGifSetPlayerFrame(self, 1)
end

function assetBridgeGifPlayerMethods:SetLooped(shouldLoop)
    if self._state == "destroyed" then
        return false, "This GIF player has been destroyed."
    end

    self.Looped = shouldLoop == true
    self._maximumPlaythroughs = self.Looped and math.huge or 1
    return true
end

function assetBridgeGifPlayerMethods:SetPlaybackSpeed(playbackSpeed)
    playbackSpeed = tonumber(playbackSpeed)
    if not playbackSpeed or playbackSpeed <= 0 then
        return false, "PlaybackSpeed must be a positive number."
    end

    self.PlaybackSpeed = math.max(0.05, playbackSpeed)
    return true
end

function assetBridgeGifPlayerMethods:SetFrame(frameIndex)
    if self._state == "destroyed" then
        return false, "This GIF player has been destroyed."
    end

    local previousPlayerState = self._state
    local wasActive = previousPlayerState == "playing" or previousPlayerState == "paused"
    self._token = self._token + 1
    local frameSetSuccess, frameSetError = assetBridgeGifSetPlayerFrame(self, frameIndex)
    if not frameSetSuccess then
        if wasActive then
            self._state = "stopped"
            self.IsPlaying = false
            self.IsPaused = false
        end
        return false, frameSetError
    end

    if wasActive then
        self._state = previousPlayerState
        self.IsPlaying = previousPlayerState == "playing"
        self.IsPaused = previousPlayerState == "paused"
        assetBridgeGifRunPlayer(self, self._token)
    end

    return true
end

function assetBridgeGifPlayerMethods:Destroy()
    if self._state == "destroyed" then
        return
    end

    self._token = self._token + 1
    self._state = "destroyed"
    self.IsPlaying = false
    self.IsPaused = false

    if self.EndedEvent then
        self.EndedEvent:Destroy()
        self.EndedEvent = nil
        self.Ended = nil
    end

    for layerIndex = #self._layers, 1, -1 do
        assetBridgeGifRemovePlayerLayer(self, self._layers[layerIndex])
    end

    local targetObject = self._target
    local originalProperties = self._originalTargetProperties
    if targetObject and targetObject.Parent and originalProperties then
        pcall(function()
            targetObject.Image = originalProperties.Image
            targetObject.ImageTransparency = originalProperties.ImageTransparency
            targetObject.BackgroundColor3 = originalProperties.BackgroundColor3
            targetObject.BackgroundTransparency = originalProperties.BackgroundTransparency
        end)
    end

    local animation = self._animation
    if animation and animation._players then
        for playerIndex = #animation._players, 1, -1 do
            if animation._players[playerIndex] == self then
                table.remove(animation._players, playerIndex)
                break
            end
        end
    end

    self._target = nil
    self._animation = nil
    self._layers = {}
    assetBridgeActiveResources[self] = nil
end

local assetBridgeGifPlayerMetatable = {
    __index = function(gifPlayer, propertyName)
        local gifMethod = assetBridgeGifPlayerMethods[propertyName]
        if gifMethod then
            return gifMethod
        end

        if propertyName == "State" then
            return rawget(gifPlayer, "_state")
        elseif propertyName == "Target" then
            return rawget(gifPlayer, "_target")
        elseif propertyName == "Animation" then
            return rawget(gifPlayer, "_animation")
        elseif propertyName == "IsDestroyed" then
            return rawget(gifPlayer, "_state") == "destroyed"
        end

        return nil
    end
}

local assetBridgeGifFrameMetatable = {
    __index = function(gifFrameData, propertyName)
        if propertyName == "ImageId" then
            local animation = rawget(gifFrameData, "_Animation")
            if animation and assetBridgeGifEnsureFrameBuilt then
                local buildSuccess, buildError = assetBridgeGifEnsureFrameBuilt(animation, rawget(gifFrameData, "Index"))
                if not buildSuccess then
                    rawset(gifFrameData, "AssetError", buildError)
                    return nil
                end
            end

            local gifFrameImageId, gifFrameAssetError = assetBridgeGetCustomAssetId(rawget(gifFrameData, "FilePath"))
            if gifFrameImageId then
                rawset(gifFrameData, "ImageId", gifFrameImageId)
            else
                rawset(gifFrameData, "AssetError", gifFrameAssetError)
            end
            return gifFrameImageId
        end
        return nil
    end
}

local function assetBridgeCreateGifAnimation(gifDownload, gifDecoded, gifOptions)
    local gifDecoder = gifDecoded.Decoder
    if not gifDecoder then
        return nil, "The GIF animation is missing its incremental decoder."
    end
    if type(assetBridgeWriteFileFunction) ~= "function" then
        return nil, "GIF frame generation requires executor writefile()."
    end

    local gifAnimationFrames = {}
    local gifAnimationDuration = 0
    for gifFrameIndex, frameMetadata in ipairs(gifDecoded.Frames) do
        gifAnimationFrames[gifFrameIndex] = setmetatable({
            Index = gifFrameIndex,
            Duration = frameMetadata.Duration,
            CompressedSize = frameMetadata.CompressedSize or 0,
            SourceWidth = frameMetadata.Width,
            SourceHeight = frameMetadata.Height,
            X = frameMetadata.X,
            Y = frameMetadata.Y,
            Disposal = frameMetadata.Disposal,
            Transparent = frameMetadata.Transparent,
            TransparentIndex = frameMetadata.TransparentIndex,
            FilePath = nil,
            FileReady = false,
            Size = 0
        }, assetBridgeGifFrameMetatable)
        gifAnimationDuration = gifAnimationDuration + frameMetadata.Duration
    end

    local gifAnimation = {
        Url = gifDownload.Url,
        Width = gifDecoded.Width,
        Height = gifDecoded.Height,
        Frames = gifAnimationFrames,
        FrameCount = gifDecoded.FrameCount,
        Duration = gifAnimationDuration,
        LoopExtensionFound = gifDecoded.LoopExtensionFound,
        LoopCount = gifDecoded.LoopCount,
        TotalPixels = gifDecoded.TotalPixels,
        TotalOutputBytes = 0,
        Stats = gifDecoder.Stats,
        Cached = gifDownload.Cached,
        Format = "gif",
        _decoder = gifDecoder,
        _backgroundPixel = gifDecoder._backgroundPixel,
        _initialTransparent = gifDecoder._initialTransparent,
        _players = {},
        _building = false,
        _buildError = nil,
        _buildOptions = gifOptions,
        _preloadFrameCount = math.clamp(math.floor(tonumber(gifOptions.PreloadFrames) or 2), 1, 4),
        _onFrameDecoded = gifOptions.OnFrameDecoded,
        _onDecodeProgress = gifOptions.OnDecodeProgress
    }

    for _, gifFrameData in ipairs(gifAnimationFrames) do
        rawset(gifFrameData, "_Animation", gifAnimation)
    end

    function gifAnimation:Destroy()
        if self._destroyed then
            return
        end
        self._destroyed = true

        for playerIndex = #self._players, 1, -1 do
            local gifPlayer = self._players[playerIndex]
            if gifPlayer then
                pcall(gifPlayer.Destroy, gifPlayer)
            end
        end
        table.clear(self._players)

        if self._decoder then
            self._decoder:Destroy()
            self._decoder = nil
        end
        table.clear(self.Frames)
        assetBridgeActiveResources[self] = nil
    end

    assetBridgeActiveResources[gifAnimation] = true

    function gifAnimation:BuildAll()
        if self._destroyed then
            return false, "This GIF animation has been destroyed."
        end
        return assetBridgeGifEnsureFrameBuilt(self, self.FrameCount)
    end

    function gifAnimation:Apply(targetImageObject)
        if self._destroyed then
            return false, "This GIF animation has been destroyed."
        end
        local appliedPlayer, appliedPlayerError = self:CreatePlayer(targetImageObject, {Looped = false})
        if not appliedPlayer then
            return false, appliedPlayerError
        end
        return true
    end

    function gifAnimation:CreatePlayer(targetImageObject, playerOptions)
        playerOptions = playerOptions or {}

        if self._destroyed then
            return nil, "This GIF animation has been destroyed."
        end
        if typeof(targetImageObject) ~= "Instance" or not (targetImageObject:IsA("ImageLabel") or targetImageObject:IsA("ImageButton")) then
            return nil, "CreatePlayer() requires an ImageLabel or ImageButton."
        end

        local hasLoopingOption = playerOptions.Looped ~= nil
        local playerLooped = hasLoopingOption and playerOptions.Looped == true or (not hasLoopingOption and self.LoopExtensionFound)
        local maximumPlaythroughs = 1

        if hasLoopingOption and playerOptions.Looped == true then
            maximumPlaythroughs = math.huge
        elseif not hasLoopingOption and self.LoopExtensionFound then
            if self.LoopCount == 0 then
                maximumPlaythroughs = math.huge
            else
                maximumPlaythroughs = (tonumber(self.LoopCount) or 0) + 1
            end
        end

        local endedEvent = assetBridgeInstanceNew("BindableEvent")
        local player = setmetatable({
            _animation = self,
            _target = targetImageObject,
            _originalTargetProperties = {
                Image = targetImageObject.Image,
                ImageTransparency = targetImageObject.ImageTransparency,
                BackgroundColor3 = targetImageObject.BackgroundColor3,
                BackgroundTransparency = targetImageObject.BackgroundTransparency
            },
            _layers = {},
            _previousFrame = nil,
            _state = "stopped",
            _token = 0,
            _maximumPlaythroughs = maximumPlaythroughs,
            CurrentFrame = 1,
            CurrentTime = 0,
            PlaybackSpeed = math.max(0.05, tonumber(playerOptions.PlaybackSpeed) or 1),
            Looped = playerLooped,
            IsPlaying = false,
            IsPaused = false,
            EndedEvent = endedEvent,
            Ended = endedEvent.Event
        }, assetBridgeGifPlayerMetatable)

        assetBridgeActiveResources[player] = true
        table.insert(self._players, player)
        targetImageObject.Image = ""
        targetImageObject.ImageTransparency = 1
        local firstFrameSuccess, firstFrameError = assetBridgeGifSetPlayerFrame(player, 1)
        if not firstFrameSuccess then
            player:Destroy()
            return nil, firstFrameError
        end
        return player
    end

    function gifAnimation:Play(targetImageObject, playerOptions)
        local gifPlayer, gifPlayerError = self:CreatePlayer(targetImageObject, playerOptions)
        if not gifPlayer then
            return nil, gifPlayerError
        end

        local playSuccess, playError = gifPlayer:Play()
        if not playSuccess then
            gifPlayer:Destroy()
            return nil, playError
        end

        return gifPlayer
    end

    assetBridgeGifEnsureFrameBuilt = function(animation, targetFrameIndex)
        if animation._destroyed then
            return false, "This GIF animation has been destroyed."
        end

        targetFrameIndex = math.clamp(math.floor(tonumber(targetFrameIndex) or 1), 1, animation.FrameCount)
        local targetFrameData = animation.Frames[targetFrameIndex]
        if targetFrameData and targetFrameData.FileReady and targetFrameData.FilePath then
            return true
        end

        while animation._building and not animation._destroyed do
            if targetFrameData and targetFrameData.FileReady and targetFrameData.FilePath then
                return true
            end
            task.wait()
        end

        if animation._destroyed then
            return false, "This GIF animation has been destroyed."
        end
        if targetFrameData and targetFrameData.FileReady and targetFrameData.FilePath then
            return true
        end

        local decoder = animation._decoder
        if not decoder or decoder._destroyed then
            return false, "The GIF decoder is no longer available."
        end
        if decoder.DecodedFrameCount >= targetFrameIndex then
            return false, "The requested GIF frame was decoded but its file is unavailable."
        end

        animation._building = true
        local initialDecodedFrameCount = decoder.DecodedFrameCount
        local requestedBuildCount = targetFrameIndex - initialDecodedFrameCount
        local decodeCallSucceeded, decodedFrames, buildError = pcall(function()
            return decoder:DecodeNextFramesParallel(
                requestedBuildCount,
                function(decodedFrame)
                local animationFrameData = animation.Frames[decodedFrame.Index]
                if animationFrameData then
                    animationFrameData.FilePath = decodedFrame.FilePath
                    animationFrameData.FileReady = true
                    animationFrameData.Size = decodedFrame.Size or 0
                    animationFrameData.OutputMode = decodedFrame.OutputMode
                    animationFrameData.DecodeTime = decodedFrame.DecodeTime
                    animationFrameData.LzwDecodeTime = decodedFrame.LzwDecodeTime
                end
                animation.TotalOutputBytes = decoder.TotalOutputBytes
                animation.Stats = decoder.Stats

                if type(animation._onFrameDecoded) == "function" then
                    pcall(animation._onFrameDecoded, decodedFrame, decoder.DecodedFrameCount, animation.FrameCount)
                end
            end,
            function(completedWorkers, workerTotal, frameIndex, succeeded, decodeError)
                if type(animation._onDecodeProgress) == "function" then
                    pcall(
                        animation._onDecodeProgress,
                        initialDecodedFrameCount + completedWorkers,
                        animation.FrameCount,
                        frameIndex,
                        succeeded,
                        decodeError
                    )
                end
            end
        )
        end)
        if not decodeCallSucceeded then
            buildError = decodedFrames
            decodedFrames = nil
        end
        animation._building = false
        animation.TotalOutputBytes = decoder.TotalOutputBytes
        animation.Stats = decoder.Stats

        if not decodedFrames then
            animation._buildError = buildError
            return false, buildError
        end

        if not targetFrameData.FileReady or not targetFrameData.FilePath then
            return false, animation._buildError or "The requested GIF frame was not generated."
        end

        animation._buildError = nil
        return true
    end

    return gifAnimation
end

function AssetBridge.GIF.Open(gifUrl, gifOptions)
    gifOptions = gifOptions or {}

    local gifDownloadOptions = {}
    for optionName, optionValue in pairs(gifOptions) do
        gifDownloadOptions[optionName] = optionValue
    end
    gifDownloadOptions.MaxBytes = math.huge

    local downloadedGif, gifDownloadError = assetBridgeDownload(gifUrl, "Image", gifDownloadOptions)
    if not downloadedGif then
        return nil, gifDownloadError
    end

    if downloadedGif.Extension ~= "gif" then
        return nil, "The supplied URL did not return a GIF image. Detected format: " .. tostring(downloadedGif.Extension)
    end

    local gifBytes = downloadedGif.Bytes
    if not gifBytes and type(assetBridgeReadFileFunction) == "function" then
        local readSuccess, readBytes = pcall(assetBridgeReadFileFunction, downloadedGif.FilePath)
        if readSuccess and type(readBytes) == "string" then
            gifBytes = readBytes
        end
    end

    if type(gifBytes) ~= "string" then
        local forcedOptions = {}
        for optionName, optionValue in pairs(gifDownloadOptions) do
            forcedOptions[optionName] = optionValue
        end
        forcedOptions.Refresh = true
        forcedOptions.Cache = false
        local freshDownload, freshDownloadError = assetBridgeDownload(gifUrl, "Image", forcedOptions)
        if not freshDownload then
            return nil, freshDownloadError
        end
        downloadedGif = freshDownload
        gifBytes = freshDownload.Bytes
    end

    if type(gifBytes) ~= "string" then
        return nil, "The GIF response was unavailable as binary data. This executor needs a binary-capable HTTP request function."
    end

    local scannedGif, scanError = assetBridgeGifScanFrames(gifBytes, gifOptions)
    if not scannedGif then
        return nil, scanError
    end

    return assetBridgeCreateIncrementalGifDecoder(downloadedGif, scannedGif, gifOptions)
end

AssetBridge.GIF.OpenIncremental = AssetBridge.GIF.Open

function AssetBridge.GIF.Fetch(gifUrl, gifOptions)
    gifOptions = gifOptions or {}

    local gifDecoder, gifOpenError = AssetBridge.GIF.Open(gifUrl, gifOptions)
    if not gifDecoder then
        return nil, gifOpenError
    end

    local decodedAnimationData = {
        Width = gifDecoder.Width,
        Height = gifDecoder.Height,
        Frames = gifDecoder.Frames,
        FrameCount = gifDecoder.FrameCount,
        Duration = gifDecoder.Duration,
        LoopExtensionFound = gifDecoder.LoopExtensionFound,
        LoopCount = gifDecoder.LoopCount,
        TotalPixels = gifDecoder.TotalPixels,
        TotalOutputBytes = 0,
        Stats = gifDecoder.Stats,
        Cached = gifDecoder.Cached,
        Decoder = gifDecoder
    }

    local gifAnimation, animationError = assetBridgeCreateGifAnimation(
        {Url = gifDecoder.Url, Cached = gifDecoder.Cached},
        decodedAnimationData,
        gifOptions
    )

    if not gifAnimation then
        gifDecoder:Destroy()
        return nil, animationError
    end

    if type(gifOptions.OnPrepared) == "function" then
        pcall(gifOptions.OnPrepared, gifAnimation)
    end

    return gifAnimation
end

local assetBridgeSoundEffectClasses = {
    reverb = "ReverbSoundEffect",
    echo = "EchoSoundEffect",
    distortion = "DistortionSoundEffect",
    chorus = "ChorusSoundEffect",
    compressor = "CompressorSoundEffect",
    equalizer = "EqualizerSoundEffect",
    pitchshift = "PitchShiftSoundEffect"
}

local assetBridgeSoundMethods = {}
local assetBridgeSoundMetatable = {}

function assetBridgeSoundMethods:Play()
    local soundInstance = rawget(self, "_sound")
    soundInstance:Play()
    rawset(self, "_state", "playing")
    return self
end

function assetBridgeSoundMethods:Pause()
    local soundInstance = rawget(self, "_sound")
    soundInstance:Pause()
    rawset(self, "_state", "paused")
    return self
end

function assetBridgeSoundMethods:Resume()
    local soundInstance = rawget(self, "_sound")
    soundInstance:Resume()
    rawset(self, "_state", "playing")
    return self
end

function assetBridgeSoundMethods:Stop()
    local soundInstance = rawget(self, "_sound")
    soundInstance:Stop()
    rawset(self, "_state", "stopped")
    return self
end

function assetBridgeSoundMethods:Destroy()
    local soundInstance = rawget(self, "_sound")
    if soundInstance then
        pcall(function()
            soundInstance:Stop()
        end)
        soundInstance:Destroy()
        rawset(self, "_sound", nil)
    end
    rawset(self, "_state", "destroyed")
    assetBridgeActiveResources[self] = nil
end

function assetBridgeSoundMethods:WaitForLoaded(timeoutSeconds)
    local soundInstance = rawget(self, "_sound")
    local timeoutAt = timeoutSeconds and (os.clock() + timeoutSeconds) or nil

    while soundInstance and not soundInstance.IsLoaded do
        if timeoutAt and os.clock() >= timeoutAt then
            return false, "Timed out while waiting for the audio to load."
        end
        task.wait(0.05)
    end

    return soundInstance ~= nil
end

function assetBridgeSoundMethods:AddEffect(effectName, effectProperties)
    local soundInstance = rawget(self, "_sound")
    local normalizedEffectName = string.lower(tostring(effectName)):gsub("soundeffect", ""):gsub("[^%w]", "")
    local effectClassName = assetBridgeSoundEffectClasses[normalizedEffectName] or tostring(effectName)

    local effectSuccess, effectInstance = pcall(assetBridgeInstanceNew, effectClassName)
    if not effectSuccess then
        return nil, "Unsupported audio effect: " .. tostring(effectName)
    end

    effectInstance.Name = "AssetBridge_" .. normalizedEffectName

    for propertyName, propertyValue in pairs(effectProperties or {}) do
        if propertyName ~= "Name" and propertyName ~= "Parent" then
            local propertySuccess, propertyError = pcall(function()
                effectInstance[propertyName] = propertyValue
            end)
            if not propertySuccess then
                effectInstance:Destroy()
                return nil, "Invalid " .. effectClassName .. " property " .. tostring(propertyName) .. ": " .. tostring(propertyError)
            end
        end
    end

    effectInstance.Parent = soundInstance
    return effectInstance
end

function assetBridgeSoundMethods:RemoveEffect(effectNameOrInstance)
    local soundInstance = rawget(self, "_sound")

    if typeof(effectNameOrInstance) == "Instance" then
        if effectNameOrInstance.Parent == soundInstance then
            effectNameOrInstance:Destroy()
            return true
        end
        return false
    end

    local wantedEffectName = string.lower(tostring(effectNameOrInstance)):gsub("soundeffect", ""):gsub("[^%w]", "")

    for _, effectInstance in ipairs(soundInstance:GetChildren()) do
        local childEffectName = string.lower(effectInstance.ClassName):gsub("soundeffect", ""):gsub("[^%w]", "")
        if childEffectName == wantedEffectName or string.lower(effectInstance.Name) == "assetbridge_" .. wantedEffectName then
            effectInstance:Destroy()
            return true
        end
    end

    return false
end

function assetBridgeSoundMethods:GetPropertyChangedSignal(propertyName)
    local soundInstance = rawget(self, "_sound")
    if propertyName == "Pitch" then
        propertyName = "PlaybackSpeed"
    elseif propertyName == "Loudness" then
        propertyName = "PlaybackLoudness"
    end
    return soundInstance:GetPropertyChangedSignal(propertyName)
end

function assetBridgeSoundMethods:GetInstance()
    return rawget(self, "_sound")
end

assetBridgeSoundMetatable.__index = function(soundWrapper, propertyName)
    local soundMethod = assetBridgeSoundMethods[propertyName]
    if soundMethod then
        return soundMethod
    end

    local soundInstance = rawget(soundWrapper, "_sound")

    if propertyName == "Instance" then
        return soundInstance
    elseif propertyName == "Pitch" then
        return soundInstance and soundInstance.PlaybackSpeed
    elseif propertyName == "Loudness" then
        return soundInstance and soundInstance.PlaybackLoudness
    elseif propertyName == "State" then
        return rawget(soundWrapper, "_state")
    elseif propertyName == "IsPaused" then
        local readSuccess, pausedValue = pcall(function()
            return soundInstance.IsPaused
        end)
        if readSuccess then
            return pausedValue
        end
        return rawget(soundWrapper, "_state") == "paused"
    elseif propertyName == "IsDestroyed" then
        return soundInstance == nil
    end

    if not soundInstance then
        return nil
    end

    local readSuccess, soundPropertyValue = pcall(function()
        return soundInstance[propertyName]
    end)

    if not readSuccess then
        return nil
    end

    if type(soundPropertyValue) == "function" then
        return function(_, ...)
            return soundPropertyValue(soundInstance, ...)
        end
    end

    return soundPropertyValue
end

assetBridgeSoundMetatable.__newindex = function(soundWrapper, propertyName, propertyValue)
    local soundInstance = rawget(soundWrapper, "_sound")

    if propertyName == "Pitch" then
        propertyName = "PlaybackSpeed"
    elseif propertyName == "Loudness" or propertyName == "PlaybackLoudness" then
        error(propertyName .. " is read-only. Use Volume to change output level.", 2)
    elseif propertyName == "Instance" or propertyName == "IsDestroyed" or propertyName == "State" then
        error(propertyName .. " is managed by AssetBridge.", 2)
    end

    if not soundInstance then
        error("This AssetBridge audio instance has been destroyed.", 2)
    end

    local writeSuccess, writeError = pcall(function()
        soundInstance[propertyName] = propertyValue
    end)

    if not writeSuccess then
        error(tostring(writeError), 2)
    end
end

local function assetBridgeCreateSoundWrapper(soundInstance)
    local soundWrapper = setmetatable({
        _sound = soundInstance,
        _state = "stopped"
    }, assetBridgeSoundMetatable)
    assetBridgeActiveResources[soundWrapper] = true
    return soundWrapper
end

local function assetBridgeCreateAudioAsset(downloadedAsset, audioOptions)
    audioOptions = audioOptions or {}
    local audioAssetId, assetIdError = assetBridgeGetCustomAssetId(downloadedAsset.FilePath)

    if not audioAssetId then
        return nil, assetIdError
    end

    local audioAsset = {
        Url = downloadedAsset.Url,
        SoundId = audioAssetId,
        FilePath = downloadedAsset.FilePath,
        Format = downloadedAsset.Extension,
        Size = downloadedAsset.Size,
        Cached = downloadedAsset.Cached
    }

    audioAsset.SoundID = audioAsset.SoundId

    function audioAsset:CreateSound(parentInstance, soundProperties)
        soundProperties = soundProperties or {}
        local soundInstance = assetBridgeInstanceNew("Sound")
        soundInstance.Name = soundProperties.Name or "AssetBridgeSound"
        soundInstance.SoundId = self.SoundId

        for propertyName, propertyValue in pairs(soundProperties) do
            if propertyName ~= "Name" and propertyName ~= "Parent" then
                local propertySuccess, propertyError = pcall(function()
                    soundInstance[propertyName] = propertyValue
                end)

                if not propertySuccess then
                    soundInstance:Destroy()
                    return nil, "Could not set Sound property " .. tostring(propertyName) .. ": " .. tostring(propertyError)
                end
            end
        end

        soundInstance.Parent = parentInstance or soundProperties.Parent or assetBridgeSoundService
        return assetBridgeCreateSoundWrapper(soundInstance)
    end

    function audioAsset:Play(parentInstance, soundProperties)
        local soundWrapper, soundError = self:CreateSound(parentInstance, soundProperties)
        if not soundWrapper then
            return nil, soundError
        end
        soundWrapper:Play()
        return soundWrapper
    end

    return audioAsset
end

function AssetBridge.Audio.Fetch(audioUrl, audioOptions)
    audioOptions = audioOptions or {}
    local downloadedAudio, downloadError = assetBridgeDownload(audioUrl, "Audio", audioOptions)

    if not downloadedAudio then
        return nil, downloadError
    end

    return assetBridgeCreateAudioAsset(downloadedAudio, audioOptions)
end

function AssetBridge.Download(url, expectedType, downloadOptions)
    if expectedType ~= "Image" and expectedType ~= "Audio" then
        return nil, "ExpectedType must be 'Image' or 'Audio'."
    end

    return assetBridgeDownload(url, expectedType, downloadOptions)
end

function AssetBridge.Configure(configuration)
    if type(configuration) ~= "table" then
        return false, "Configure() expects a table."
    end

    for configurationName, configurationValue in pairs(configuration) do
        AssetBridge.Config[configurationName] = configurationValue
    end

    assetBridgeRefreshCapabilities()
    return true
end

function AssetBridge.GetCapabilities()
    return assetBridgeRefreshCapabilities()
end

function AssetBridge.Cache.ClearMemory()
    table.clear(assetBridgeMemoryCache)
end

function AssetBridge.Cache.GetMemoryCount()
    local cachedAssetCount = 0

    for _ in pairs(assetBridgeMemoryCache) do
        cachedAssetCount = cachedAssetCount + 1
    end

    return cachedAssetCount
end

function AssetBridge.Cache.ClearDisk()
    if type(assetBridgeDeleteFileFunction) ~= "function" then
        return false, "This executor does not expose delfile()."
    end

    local listFilesFunction = assetBridgeSafeGetGlobal("listfiles")
    local deletedCount = 0

    for trackedFilePath in pairs(assetBridgeTrackedFiles) do
        local deleteSuccess = pcall(assetBridgeDeleteFileFunction, trackedFilePath)
        if deleteSuccess then
            deletedCount = deletedCount + 1
        end
        assetBridgeTrackedFiles[trackedFilePath] = nil
    end
    local function clearCacheFolder(folderPath)
        local listSuccess, listedEntries = pcall(listFilesFunction, folderPath)
        if not listSuccess or type(listedEntries) ~= "table" then
            return
        end

        for _, listedPath in ipairs(listedEntries) do
            local entryPath = tostring(listedPath)
            local isDirectory = false
            if type(assetBridgeIsFolderFunction) == "function" then
                local folderCheckSuccess, folderCheckResult = pcall(assetBridgeIsFolderFunction, entryPath)
                isDirectory = folderCheckSuccess and folderCheckResult == true
            end
            if not isDirectory then
                local nestedListSuccess, nestedEntries = pcall(listFilesFunction, entryPath)
                isDirectory = nestedListSuccess and type(nestedEntries) == "table"
            end

            if isDirectory then
                clearCacheFolder(entryPath)
            else
                local deleteSuccess = pcall(assetBridgeDeleteFileFunction, entryPath)
                if deleteSuccess then
                    deletedCount = deletedCount + 1
                end
            end
        end
    end

    if type(listFilesFunction) == "function" then
        for _, cacheFolderPath in pairs(assetBridgeCacheDirectories) do
            clearCacheFolder(cacheFolderPath)
        end
    end

    return true, deletedCount
end

function AssetBridge.Close()
    if assetBridgeCloseInProgress then
        return false, "AssetBridge is already closing."
    end
    assetBridgeCloseInProgress = true
    assetBridgeSessionGeneration = assetBridgeSessionGeneration + 1

    local activeResources = {}
    for activeResource in pairs(assetBridgeActiveResources) do
        activeResources[#activeResources + 1] = activeResource
    end

    for _, activeResource in ipairs(activeResources) do
        local destroyFunction = activeResource.Destroy
        if type(destroyFunction) == "function" then
            pcall(destroyFunction, activeResource)
        end
    end

    table.clear(assetBridgeActiveResources)
    AssetBridge.Cache.ClearMemory()
    local cleanupSuccess, deletedFileCountOrError = AssetBridge.Cache.ClearDisk()
    assetBridgeCloseInProgress = false
    if not cleanupSuccess then
        return false, deletedFileCountOrError
    end
    return true, deletedFileCountOrError
end

AssetBridge.Destroy = AssetBridge.Close

assetBridgeRefreshCapabilities()

return AssetBridge
