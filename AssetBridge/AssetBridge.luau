local AssetBridge = {
    Name = "AssetBridge",
    Version = "0.1.1",
    Config = {
        Cache = true,
        MaxBytes = 52428800
    },
    Image = {},
    Audio = {},
    Cache = {},
    Capabilities = {}
}

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

    return assetBridgeCreateImageAsset(downloadedImage)
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
        if string.match(fileName, "^AssetBridge_[%da-fA-F]+%.[%w]+$") then
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
