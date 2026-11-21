local AssetBridge = {
    Name = "AssetBridge",
    Version = "0.2.1",
    Config = {
        Cache = true,
        MaxBytes = 52428800,
        GIFMaxFrames = 120,
        GIFMaxPixels = 1048576,
        GIFMaxTotalPixels = 99999999999999999999999999999999999999999999999999999999999999,
        GIFMaxOutputBytes = 40000000,
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
local assetBridgeRequestFunction = request or http_request
local assetBridgeWriteFileFunction = writefile
local assetBridgeReadFileFunction = readfile
local assetBridgeIsFileFunction = isfile
local assetBridgeDeleteFileFunction = delfile
local assetBridgeGetCustomAssetFunction = getcustomasset or getsynasset
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

local function assetBridgeBuildCachePath(assetBridgeUrl, assetBridgeExtension)
    return "AssetBridge_" .. assetBridgeHashString(assetBridgeUrl) .. "." .. assetBridgeExtension
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

    local assetBridgeCachePath = assetBridgeBuildCachePath(assetBridgeUrl, assetBridgeKnownExtension)

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

    local assetBridgeCachePath = assetBridgeBuildCachePath(assetBridgeNormalizedUrl, assetBridgeDetectedExtension)
    local assetBridgeWriteSuccess, assetBridgeWriteError = pcall(assetBridgeWriteFileFunction, assetBridgeCachePath, assetBridgeDownloadedBytes)

    if not assetBridgeWriteSuccess then
        return nil, "Could not write the downloaded file: " .. tostring(assetBridgeWriteError)
    end

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
    local gifDictionary = {}
    local gifBitPosition = 0
    local gifBytePosition = 1
    local gifBitBuffer = 0
    local gifBitCount = 0
    local gifOutputParts = {}
    local gifOutputLength = 0
    local gifPreviousEntry = nil

    local function assetBridgeGifReadCode(codeWidth)
        while gifBitCount < codeWidth do
            local nextByte = string.byte(gifCompressedBytes, gifBytePosition)
            if not nextByte then
                return nil
            end
            gifBitBuffer = gifBitBuffer + nextByte * (2 ^ gifBitCount)
            gifBitCount = gifBitCount + 8
            gifBytePosition = gifBytePosition + 1
        end

        local codeModulus = 2 ^ codeWidth
        local decodedCode = gifBitBuffer % codeModulus
        gifBitBuffer = math.floor(gifBitBuffer / codeModulus)
        gifBitCount = gifBitCount - codeWidth
        return decodedCode
    end

    local function assetBridgeGifResetDictionary()
        gifDictionary = {}
        for literalIndex = 0, gifClearCode - 1 do
            gifDictionary[literalIndex] = string.char(literalIndex)
        end
        gifCodeSize = gifMinimumCodeSize + 1
        gifNextCode = gifEndCode + 1
        gifPreviousEntry = nil
    end

    assetBridgeGifResetDictionary()

    local processedCodeCount = 0
    while true do
        local currentCode = assetBridgeGifReadCode(gifCodeSize)
        processedCodeCount = processedCodeCount + 1
        if gifYieldEveryCodes and gifYieldEveryCodes > 0 and processedCodeCount % gifYieldEveryCodes == 0 then
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
            local currentEntry = gifDictionary[currentCode]

            if not currentEntry and currentCode == gifNextCode and gifPreviousEntry then
                currentEntry = gifPreviousEntry .. string.sub(gifPreviousEntry, 1, 1)
            end

            if not currentEntry then
                return nil, "Invalid GIF LZW code encountered."
            end

            gifOutputParts[#gifOutputParts + 1] = currentEntry
            gifOutputLength = gifOutputLength + #currentEntry

            if gifOutputLength > gifExpectedPixelCount then
                return nil, "GIF frame decoded to more pixels than its dimensions allow."
            end

            if gifPreviousEntry and gifNextCode < 4096 then
                gifDictionary[gifNextCode] = gifPreviousEntry .. string.sub(currentEntry, 1, 1)
                gifNextCode = gifNextCode + 1

                if gifNextCode >= 2 ^ gifCodeSize and gifCodeSize < 12 then
                    gifCodeSize = gifCodeSize + 1
                end
            end

            gifPreviousEntry = currentEntry
        end
    end

    local decodedPixels = table.concat(gifOutputParts)
    if #decodedPixels < gifExpectedPixelCount then
        return nil, "GIF frame did not contain enough decoded pixels."
    end

    return decodedPixels
end

local function assetBridgeGifCloneCanvas(gifCanvasRows, gifHeight)
    local clonedCanvasRows = {}
    for gifRowIndex = 1, gifHeight do
        clonedCanvasRows[gifRowIndex] = gifCanvasRows[gifRowIndex]
    end
    return clonedCanvasRows
end

local function assetBridgeGifCreateCanvas(gifWidth, gifHeight, gifFillPixel)
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

    for gifY = clippedStartY, clippedEndY - 1 do
        local gifRow = {}
        local originalRow = gifCanvasRows[gifY + 1]
        for gifX = 1, gifCanvasWidth do
            gifRow[gifX] = originalRow[gifX]
        end
        for gifX = clippedStartX, clippedEndX - 1 do
            gifRow[gifX + 1] = gifFillPixel
        end
        gifCanvasRows[gifY + 1] = gifRow
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

local function assetBridgeGifEncodeStoredZlib(gifRawImageBytes, yieldEveryBytes)
    local deflateBlocks = {}
    local rawOffset = 1

    while rawOffset <= #gifRawImageBytes do
        local blockLength = math.min(65535, #gifRawImageBytes - rawOffset + 1)
        local isFinalBlock = rawOffset + blockLength - 1 >= #gifRawImageBytes
        local blockHeader = isFinalBlock and 1 or 0
        local inverseBlockLength = 65535 - blockLength

        deflateBlocks[#deflateBlocks + 1] = string.char(blockHeader)
            .. assetBridgeGifPackUInt16LE(blockLength)
            .. assetBridgeGifPackUInt16LE(inverseBlockLength)
            .. string.sub(gifRawImageBytes, rawOffset, rawOffset + blockLength - 1)

        rawOffset = rawOffset + blockLength
    end

    return string.char(120, 1) .. table.concat(deflateBlocks) .. assetBridgeGifPackUInt32BE(assetBridgeGifAdler32(gifRawImageBytes, yieldEveryBytes))
end

local function assetBridgeGifEncodePNG(gifWidth, gifHeight, gifCanvasRows, yieldEveryRows)
    local pngScanlines = {}

    for gifY = 1, gifHeight do
        pngScanlines[#pngScanlines + 1] = "\0" .. table.concat(gifCanvasRows[gifY])
        if yieldEveryRows and yieldEveryRows > 0 and gifY % yieldEveryRows == 0 then
            task.wait()
        end
    end

    local rawImageBytes = table.concat(pngScanlines)
    local yieldEveryBytes = yieldEveryRows and yieldEveryRows > 0 and math.max(4096, yieldEveryRows * gifWidth * 4) or nil
    local compressedImageBytes = assetBridgeGifEncodeStoredZlib(rawImageBytes, yieldEveryBytes)
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

    return "\137PNG\r\n\26\n" .. headerChunk .. imageChunk .. endChunk
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

    local maximumGifPixels = tonumber(gifOptions.MaxPixels) or tonumber(AssetBridge.Config.GIFMaxPixels) or 1048576
    local maximumGifFrames = tonumber(gifOptions.MaxFrames) or tonumber(AssetBridge.Config.GIFMaxFrames) or 120
    local maximumGifTotalPixels = tonumber(gifOptions.MaxTotalPixels) or tonumber(AssetBridge.Config.GIFMaxTotalPixels) or 10000000
    local maximumGifOutputBytes = tonumber(gifOptions.MaxOutputBytes) or tonumber(AssetBridge.Config.GIFMaxOutputBytes) or 40000000

    local logicalScreenPixels = gifCanvasWidth * gifCanvasHeight
    if logicalScreenPixels > maximumGifPixels then
        return nil, "GIF dimensions exceed the configured GIFMaxPixels limit."
    end

    local globalColorTable = nil
    if bit32.band(gifScreenPacked, 128) ~= 0 then
        local globalColorCount = 2 ^ (bit32.band(gifScreenPacked, 7) + 1)
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

            if #gifFrames >= maximumGifFrames then
                return nil, "GIF exceeds the configured GIFMaxFrames limit."
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
            if framePixelCount > maximumGifPixels then
                return nil, "GIF frame dimensions exceed the configured GIFMaxPixels limit."
            end

            gifTotalPixels = gifTotalPixels + logicalScreenPixels

            if gifTotalPixels > maximumGifTotalPixels then
                return nil, "GIF exceeds the configured GIFMaxTotalPixels decoding limit."
            end

            local localColorTable = nil
            if bit32.band(imagePacked, 128) ~= 0 then
                local localColorCount = 2 ^ (bit32.band(imagePacked, 7) + 1)
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
            if gifTotalOutputBytes > maximumGifOutputBytes then
                return nil, "Decoded GIF frames exceed the configured GIFMaxOutputBytes limit."
            end

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
    local maximumGifPixels = tonumber(gifOptions.MaxPixels) or tonumber(AssetBridge.Config.GIFMaxPixels) or 1048576
    local maximumGifFrames = tonumber(gifOptions.MaxFrames) or tonumber(AssetBridge.Config.GIFMaxFrames) or 120
    local maximumGifTotalPixels = tonumber(gifOptions.MaxTotalPixels) or tonumber(AssetBridge.Config.GIFMaxTotalPixels) or 10000000

    if logicalScreenPixels > maximumGifPixels then
        return nil, "GIF dimensions exceed the configured GIFMaxPixels limit."
    end

    local globalColorTable = nil
    if bit32.band(gifScreenPacked, 128) ~= 0 then
        local globalColorCount = 2 ^ (bit32.band(gifScreenPacked, 7) + 1)
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
            if #gifFrames >= maximumGifFrames then
                return nil, "GIF exceeds the configured GIFMaxFrames limit."
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
            if framePixelCount > maximumGifPixels then
                return nil, "GIF frame dimensions exceed the configured GIFMaxPixels limit."
            end

            gifTotalPixels = gifTotalPixels + logicalScreenPixels
            if gifTotalPixels > maximumGifTotalPixels then
                return nil, "GIF exceeds the configured GIFMaxTotalPixels decoding limit."
            end

            local localColorTable = nil
            if bit32.band(imagePacked, 128) ~= 0 then
                local localColorCount = 2 ^ (bit32.band(imagePacked, 7) + 1)
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

local function assetBridgeGifIncrementalDecodeFrame(gifDecoder)
    if gifDecoder._destroyed then
        return nil, "This GIF decoder has been destroyed."
    end

    local nextFrameIndex = gifDecoder.DecodedFrameCount + 1
    if nextFrameIndex > gifDecoder.FrameCount then
        return nil, "All GIF frames have already been decoded."
    end

    local frameMetadata = gifDecoder.Frames[nextFrameIndex]
    local canvasRows = gifDecoder._canvasRows

    if gifDecoder._previousGraphicFrame then
        local previousFrame = gifDecoder._previousGraphicFrame
        if previousFrame.Disposal == 2 then
            local disposalPixel = previousFrame.Transparent and gifDecoder._transparentPixel or gifDecoder._backgroundPixel
            assetBridgeGifFillCanvasRect(
                canvasRows,
                gifDecoder.Width,
                gifDecoder.Height,
                previousFrame.X,
                previousFrame.Y,
                previousFrame.Width,
                previousFrame.Height,
                disposalPixel
            )
        elseif previousFrame.Disposal == 3 then
            canvasRows = previousFrame.Restore
            gifDecoder._canvasRows = canvasRows
        end
        gifDecoder._previousGraphicFrame = nil
    end

    local framePixelCount = frameMetadata.Width * frameMetadata.Height
    local decodeStartedAt = os.clock()
    local decodedFramePixels, frameDecodeError = assetBridgeGifDecodeLZW(
        frameMetadata.CompressedData,
        frameMetadata.LzwMinimumCodeSize,
        framePixelCount,
        gifDecoder._yieldEveryCodes
    )
    if not decodedFramePixels then
        return nil, frameDecodeError
    end

    local restoreCanvas = assetBridgeGifCloneCanvas(canvasRows, gifDecoder.Height)
    local reorderedFramePixels = {}
    local frameSourceIndex = 0

    if frameMetadata.Interlaced then
        local interlacePasses = {
            {Start = 0, Step = 8},
            {Start = 4, Step = 8},
            {Start = 2, Step = 4},
            {Start = 1, Step = 2}
        }

        for _, interlacePass in ipairs(interlacePasses) do
            local destinationY = interlacePass.Start
            while destinationY < frameMetadata.Height do
                local destinationRow = {}
                for frameXPosition = 1, frameMetadata.Width do
                    frameSourceIndex = frameSourceIndex + 1
                    destinationRow[frameXPosition] = string.byte(decodedFramePixels, frameSourceIndex)
                end
                reorderedFramePixels[destinationY + 1] = destinationRow
                destinationY = destinationY + interlacePass.Step
            end
        end
    else
        for destinationY = 1, frameMetadata.Height do
            local destinationRow = {}
            for frameXPosition = 1, frameMetadata.Width do
                frameSourceIndex = frameSourceIndex + 1
                destinationRow[frameXPosition] = string.byte(decodedFramePixels, frameSourceIndex)
            end
            reorderedFramePixels[destinationY] = destinationRow
            if gifDecoder._yieldEveryRows > 0 and destinationY % gifDecoder._yieldEveryRows == 0 then
                task.wait()
            end
        end
    end

    local frameStartY = math.max(0, frameMetadata.Y)
    local frameEndY = math.min(gifDecoder.Height, frameMetadata.Y + frameMetadata.Height)
    local frameStartX = math.max(0, frameMetadata.X)
    local frameEndX = math.min(gifDecoder.Width, frameMetadata.X + frameMetadata.Width)

    for canvasY = frameStartY, frameEndY - 1 do
        local destinationCanvasRow = {}
        local previousCanvasRow = canvasRows[canvasY + 1]
        for canvasX = 1, gifDecoder.Width do
            destinationCanvasRow[canvasX] = previousCanvasRow[canvasX]
        end

        local sourceFrameRow = reorderedFramePixels[canvasY - frameMetadata.Y + 1]
        if sourceFrameRow then
            for canvasX = frameStartX, frameEndX - 1 do
                local colorIndex = sourceFrameRow[canvasX - frameMetadata.X + 1]
                if colorIndex ~= nil and colorIndex ~= frameMetadata.TransparentIndex then
                    local pixelBytes = frameMetadata.ColorTable[colorIndex]
                    if not pixelBytes then
                        return nil, "GIF frame references a color that is missing from its palette."
                    end
                    destinationCanvasRow[canvasX + 1] = pixelBytes
                end
            end
        end

        canvasRows[canvasY + 1] = destinationCanvasRow
        if gifDecoder._yieldEveryRows > 0 and (canvasY - frameStartY + 1) % gifDecoder._yieldEveryRows == 0 then
            task.wait()
        end
    end

    local pngFrameBytes, pngFrameError = assetBridgeGifEncodePNG(
        gifDecoder.Width,
        gifDecoder.Height,
        canvasRows,
        gifDecoder._yieldEveryRows
    )
    if not pngFrameBytes then
        return nil, pngFrameError
    end

    gifDecoder.TotalOutputBytes = gifDecoder.TotalOutputBytes + #pngFrameBytes
    if gifDecoder.TotalOutputBytes > gifDecoder._maximumOutputBytes then
        return nil, "Decoded GIF frames exceed the configured GIFMaxOutputBytes limit."
    end

    local animationHash = assetBridgeHashString(gifDecoder.Url)
    local frameFilePath = "AssetBridge_GIF_" .. animationHash .. "_Frame_" .. string.format("%04d", nextFrameIndex) .. ".png"
    local useExistingFile = not gifDecoder._refresh and assetBridgeFileExists(frameFilePath)

    if not useExistingFile then
        if type(assetBridgeWriteFileFunction) ~= "function" then
            return nil, "GIF frame generation requires executor writefile()."
        end
        local writeSuccess, writeError = pcall(assetBridgeWriteFileFunction, frameFilePath, pngFrameBytes)
        if not writeSuccess then
            return nil, "Could not write decoded GIF frame " .. tostring(nextFrameIndex) .. ": " .. tostring(writeError)
        end
    end

    local frameImageId, frameAssetError = assetBridgeGetCustomAssetId(frameFilePath)
    if not frameImageId then
        return nil, "Could not create local asset for GIF frame " .. tostring(nextFrameIndex) .. ": " .. tostring(frameAssetError)
    end

    local frameResult = {
        Index = nextFrameIndex,
        ImageId = frameImageId,
        FilePath = frameFilePath,
        Duration = frameMetadata.Duration,
        Size = #pngFrameBytes,
        CompressedSize = frameMetadata.CompressedSize,
        DecodeTime = os.clock() - decodeStartedAt,
        X = frameMetadata.X,
        Y = frameMetadata.Y,
        Width = gifDecoder.Width,
        Height = gifDecoder.Height,
        SourceWidth = frameMetadata.Width,
        SourceHeight = frameMetadata.Height,
        Disposal = frameMetadata.Disposal,
        Transparent = frameMetadata.Transparent,
        Interlaced = frameMetadata.Interlaced
    }

    gifDecoder.DecodedFrames[nextFrameIndex] = frameResult
    gifDecoder.DecodedFrameCount = nextFrameIndex
    gifDecoder.CurrentFrame = nextFrameIndex
    gifDecoder._previousGraphicFrame = {
        Disposal = frameMetadata.Disposal,
        X = frameMetadata.X,
        Y = frameMetadata.Y,
        Width = frameMetadata.Width,
        Height = frameMetadata.Height,
        Transparent = frameMetadata.Transparent,
        Restore = restoreCanvas
    }

    return frameResult
end

function assetBridgeGifDecoderMethods:DecodeNextFrame()
    return assetBridgeGifIncrementalDecodeFrame(self)
end

function assetBridgeGifDecoderMethods:GetDecodedFrame(frameIndex)
    frameIndex = math.floor(tonumber(frameIndex) or 0)
    return self.DecodedFrames[frameIndex]
end

function assetBridgeGifDecoderMethods:Reset()
    if self._destroyed then
        return false, "This GIF decoder has been destroyed."
    end
    local initialPixel = self._initialTransparent and self._transparentPixel or self._backgroundPixel
    self._canvasRows = assetBridgeGifCreateCanvas(self.Width, self.Height, initialPixel)
    self._previousGraphicFrame = nil
    self.DecodedFrames = {}
    self.DecodedFrameCount = 0
    self.CurrentFrame = 0
    self.TotalOutputBytes = 0
    return true
end

function assetBridgeGifDecoderMethods:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    self._canvasRows = nil
    self._previousGraphicFrame = nil
    self.DecodedFrames = {}
    self.Frames = {}
    self._gifBytes = nil
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
    if type(assetBridgeGetCustomAssetFunction) ~= "function" then
        return nil, "GIF rendering requires getcustomasset() or getsynasset()."
    end

    local transparentPixel = string.char(0, 0, 0, 0)
    local backgroundPixel = gifScanned.BackgroundPixel or transparentPixel
    local initialPixel = gifScanned.InitialTransparent and transparentPixel or backgroundPixel

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
        Format = "gif",
        Cached = gifDownload.Cached,
        _canvasRows = assetBridgeGifCreateCanvas(gifScanned.Width, gifScanned.Height, initialPixel),
        _backgroundPixel = backgroundPixel,
        _transparentPixel = transparentPixel,
        _initialTransparent = gifScanned.InitialTransparent,
        _previousGraphicFrame = nil,
        _maximumOutputBytes = tonumber(gifOptions.MaxOutputBytes) or tonumber(AssetBridge.Config.GIFMaxOutputBytes) or 40000000,
        _yieldEveryRows = math.max(0, math.floor(tonumber(gifOptions.YieldEveryRows) or 24)),
        _yieldEveryCodes = math.max(0, math.floor(tonumber(gifOptions.YieldEveryCodes) or 8192)),
        _refresh = gifOptions.Refresh == true,
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

    return decoder
end

local assetBridgeGifPlayerMethods = {}

local function assetBridgeGifSetPlayerFrame(gifPlayer, gifFrameIndex)
    local gifAnimation = gifPlayer._animation
    local gifTarget = gifPlayer._target

    gifFrameIndex = math.floor(tonumber(gifFrameIndex) or 1)
    gifFrameIndex = math.clamp(gifFrameIndex, 1, gifAnimation.FrameCount)

    gifPlayer.CurrentFrame = gifFrameIndex
    gifPlayer.CurrentTime = 0
    for precedingFrameIndex = 1, gifFrameIndex - 1 do
        gifPlayer.CurrentTime = gifPlayer.CurrentTime + gifAnimation.Frames[precedingFrameIndex].Duration
    end

    if gifTarget and gifTarget.Parent then
        gifTarget.Image = gifAnimation.Frames[gifFrameIndex].ImageId
    end
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

                if gifPlayer._target and gifPlayer._target.Parent then
                    gifPlayer._target.Image = gifCurrentFrameData.ImageId
                end

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

                        assetBridgeGifSetPlayerFrame(gifPlayer, 1)
                    else
                        assetBridgeGifSetPlayerFrame(gifPlayer, gifPlayer.CurrentFrame + 1)
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
        assetBridgeGifSetPlayerFrame(self, 1)
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
    assetBridgeGifSetPlayerFrame(self, 1)
    return true
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
    assetBridgeGifSetPlayerFrame(self, frameIndex)

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

local function assetBridgeCreateGifAnimation(gifDownload, gifDecoded, gifOptions)
    local gifAnimationHash = assetBridgeHashString(gifDownload.Url)
    local gifAnimationFrames = {}

    if type(assetBridgeWriteFileFunction) ~= "function" then
        return nil, "GIF frame generation requires executor writefile()."
    end

    if type(assetBridgeGetCustomAssetFunction) ~= "function" then
        return nil, "GIF playback requires getcustomasset() or getsynasset()."
    end

    for gifFrameIndex, decodedFrame in ipairs(gifDecoded.Frames) do
        local frameFilePath = "AssetBridge_GIF_" .. gifAnimationHash .. "_Frame_" .. string.format("%04d", gifFrameIndex) .. ".png"
        local frameAlreadyCached = assetBridgeFileExists(frameFilePath) and not gifOptions.Refresh

        if not frameAlreadyCached then
            local frameWriteSuccess, frameWriteError = pcall(assetBridgeWriteFileFunction, frameFilePath, decodedFrame.Bytes)
            if not frameWriteSuccess then
                return nil, "Could not write decoded GIF frame " .. tostring(gifFrameIndex) .. ": " .. tostring(frameWriteError)
            end
        end

        local frameImageId, frameAssetError = assetBridgeGetCustomAssetId(frameFilePath)
        if not frameImageId then
            return nil, "Could not create local asset for GIF frame " .. tostring(gifFrameIndex) .. ": " .. tostring(frameAssetError)
        end

        gifAnimationFrames[gifFrameIndex] = {
            Index = gifFrameIndex,
            ImageId = frameImageId,
            FilePath = frameFilePath,
            Duration = decodedFrame.Duration,
            Size = #decodedFrame.Bytes
        }
    end

    local gifAnimationDuration = 0
    for _, gifFrameData in ipairs(gifAnimationFrames) do
        gifAnimationDuration = gifAnimationDuration + gifFrameData.Duration
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
        TotalOutputBytes = gifDecoded.TotalOutputBytes,
        Cached = gifDownload.Cached,
        Format = "gif"
    }

    function gifAnimation:Apply(targetImageObject)
        if typeof(targetImageObject) ~= "Instance" or not (targetImageObject:IsA("ImageLabel") or targetImageObject:IsA("ImageButton")) then
            return false, "GIF animations can only be applied to ImageLabel or ImageButton instances."
        end

        targetImageObject.Image = self.Frames[1].ImageId
        return true
    end

    function gifAnimation:CreatePlayer(targetImageObject, playerOptions)
        playerOptions = playerOptions or {}

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

        assetBridgeGifSetPlayerFrame(player, 1)
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

    return gifAnimation
end

function AssetBridge.GIF.Open(gifUrl, gifOptions)
    gifOptions = gifOptions or {}

    local downloadedGif, gifDownloadError = assetBridgeDownload(gifUrl, "Image", gifOptions)
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
        for optionName, optionValue in pairs(gifOptions) do
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

    if gifOptions.PerFrame == true then
        return AssetBridge.GIF.Open(gifUrl, gifOptions)
    end

    local downloadedGif, gifDownloadError = assetBridgeDownload(gifUrl, "Image", gifOptions)
    if not downloadedGif then
        return nil, gifDownloadError
    end

    if downloadedGif.Extension ~= "gif" then
        return nil, "The supplied URL did not return a GIF image. Detected format: " .. tostring(downloadedGif.Extension)
    end

    local gifBytes = downloadedGif.Bytes
    if not gifBytes and type(assetBridgeReadFileFunction) == "function" then
        local readGifSuccess, readGifBytes = pcall(assetBridgeReadFileFunction, downloadedGif.FilePath)
        if readGifSuccess and type(readGifBytes) == "string" then
            gifBytes = readGifBytes
        end
    end

    if type(gifBytes) ~= "string" then
        local forcedDownloadOptions = {}
        for optionName, optionValue in pairs(gifOptions) do
            forcedDownloadOptions[optionName] = optionValue
        end
        forcedDownloadOptions.Refresh = true
        forcedDownloadOptions.Cache = false

        local freshGifDownload, freshGifDownloadError = assetBridgeDownload(gifUrl, "Image", forcedDownloadOptions)
        if not freshGifDownload then
            return nil, freshGifDownloadError
        end

        downloadedGif = freshGifDownload
        gifBytes = freshGifDownload.Bytes
    end

    if type(gifBytes) ~= "string" then
        return nil, "The GIF response was unavailable as binary data. This executor needs a binary-capable HTTP request function."
    end

    local decodedGif, gifDecodeError = assetBridgeGifDecode(gifBytes, gifOptions)
    if not decodedGif then
        return nil, gifDecodeError
    end

    return assetBridgeCreateGifAnimation(downloadedGif, decodedGif, gifOptions)
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
    return setmetatable({
        _sound = soundInstance,
        _state = "stopped"
    }, assetBridgeSoundMetatable)
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
    if type(listFilesFunction) ~= "function" then
        return false, "This executor does not expose listfiles()."
    end

    local listSuccess, listedFiles = pcall(listFilesFunction, "")
    if not listSuccess or type(listedFiles) ~= "table" then
        return false, "Could not list files in the executor root."
    end

    local deletedCount = 0

    for _, filePath in ipairs(listedFiles) do
        local fileName = tostring(filePath):match("([^/\\]+)$") or tostring(filePath)
        if string.match(fileName, "^AssetBridge_[%w_%-]+%.[%w]+$") then
            local deleteSuccess = pcall(assetBridgeDeleteFileFunction, filePath)
            if deleteSuccess then
                deletedCount = deletedCount + 1
            end
        end
    end

    table.clear(assetBridgeMemoryCache)
    return true, deletedCount
end

assetBridgeRefreshCapabilities()

return AssetBridge
