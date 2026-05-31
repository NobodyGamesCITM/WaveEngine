local PP_OWNER_NAME = "MainCamera"
local TRIGGER_TAG   = "Player"

--  VALORES DENTRO DE LA ZONA
local zone = {
    bloomEnabled   = true,
    bloomIntensity = 1.5,
    bloomThreshold = 0.8,
    bloomSoftKnee  = 0.5,
    bloomClamp     = 65472.0,
    bloomDiffusion = 7.0,
    bloomTintR = 1.0, bloomTintG = 0.9, bloomTintB = 0.8,

    colorGradingEnabled = true,
    exposure            = 1.2,
    contrast            = 1.1,
    saturation          = 1.3,
    temperature         = 500.0,
    colorGradingTint    = 0.0,
    toneMapper          = 0,
    colorFilterR = 1.0, colorFilterG = 0.95, colorFilterB = 0.9,
    gamma               = 1.0,

    vignetteEnabled    = true,
    vignetteIntensity  = 0.45,
    vignetteSmoothness = 0.4,
    vignetteRoundness  = 1.0,
    vignetteColorR = 0.0, vignetteColorG = 0.0, vignetteColorB = 0.0, vignetteColorA = 1.0,

    caEnabled = false, caIntensity = 0.0,

    distortionEnabled = false, distortionIntensity = 0.0,

    dofEnabled   = true,
    dofDistance  = 15.0,
    dofRange     = 5.0,
    dofStrength  = 1.2,
    dofTiltShift = false,
    dofFarTintR = 0.0, dofFarTintG = 0.0, dofFarTintB = 0.0,
    dofTintIntensity = 0.0,

    autoExposureEnabled = false,
    autoExposureMin = 0.1, autoExposureMax = 2.0, autoExposureSpeed = 1.0,

    grainEnabled = true, grainIntensity = 0.08, grainSize = 1.6,

    blurEnabled = false, blurIntensity = 1.0, blurSpread = 1.0,

    radialBlurEnabled = false, radialBlurIntensity = 0.0,
    radialBlurCenterX = 0.5, radialBlurCenterY = 0.5,

    sharpenEnabled = false, sharpenIntensity = 0.5,

    fogEnabled       = true,
    fogMode          = 0,
    fogColorR = 0.5, fogColorG = 0.6, fogColorB = 0.75,
    fogDensity       = 0.03,
    fogStart         = 10.0,
    fogEnd           = 80.0,
    fogHeightFalloff = 0.1,
    fogUseHeight     = false,
    fogHeightStart   = 0.0,
}

--  VALORES DEFAULT
local default = {

    bloomEnabled   = true,
    bloomIntensity = 1.0,
    bloomThreshold = 1.0,
    bloomSoftKnee  = 0.5,
    bloomClamp     = 65472.0,
    bloomDiffusion = 7.0,
    bloomTintR = 1.0, bloomTintG = 1.0, bloomTintB = 1.0,

    colorGradingEnabled = true,
    exposure            = 1.0,
    contrast            = 1.0,
    saturation          = 1.0,
    temperature         = 0.0,
    colorGradingTint    = 0.0,
    toneMapper          = 0,
    colorFilterR = 1.0, colorFilterG = 1.0, colorFilterB = 1.0,
    gamma               = 1.0,

    vignetteEnabled    = false,
    vignetteIntensity  = 0.4,
    vignetteSmoothness = 0.2,
    vignetteRoundness  = 1.0,
    vignetteColorR = 0.0, vignetteColorG = 0.0, vignetteColorB = 0.0, vignetteColorA = 1.0,

    caEnabled = false, caIntensity = 0.0,

    distortionEnabled = false, distortionIntensity = 0.0,

    dofEnabled   = false,
    dofDistance  = 10.0,
    dofRange     = 3.0,
    dofStrength  = 1.0,
    dofTiltShift = false,
    dofFarTintR = 0.0, dofFarTintG = 0.0, dofFarTintB = 0.0,
    dofTintIntensity = 0.0,

    autoExposureEnabled = false,
    autoExposureMin = 0.1, autoExposureMax = 2.0, autoExposureSpeed = 1.0,

    grainEnabled = false, grainIntensity = 0.1, grainSize = 1.6,

    blurEnabled = false, blurIntensity = 1.0, blurSpread = 1.0,

    radialBlurEnabled = false, radialBlurIntensity = 0.0,
    radialBlurCenterX = 0.5, radialBlurCenterY = 0.5,

    sharpenEnabled = false, sharpenIntensity = 0.5,

    fogEnabled       = false,
    fogMode          = 0,
    fogColorR = 0.7, fogColorG = 0.8, fogColorB = 0.9,
    fogDensity       = 0.02,
    fogStart         = 10.0,
    fogEnd           = 100.0,
    fogHeightFalloff = 0.1,
    fogUseHeight     = false,
    fogHeightStart   = 0.0,
}

local insideZone = false

local function ApplyValues(v)
    local ppOwner = GameObject.Find(PP_OWNER_NAME)
    if not ppOwner then
        Engine.Log("[PostProcessingZone] ERROR: GameObject '" .. PP_OWNER_NAME .. "' no encontrado.")
        return
    end

    local pp = ppOwner:GetComponent("PostProcessing")
    if not pp then
        Engine.Log("[PostProcessingZone] ERROR: '" .. PP_OWNER_NAME .. "' no tiene ComponentPostProcessing.")
        return
    end

    pp:SetBloomEnabled(v.bloomEnabled)
    pp:SetBloomIntensity(v.bloomIntensity)
    pp:SetBloomThreshold(v.bloomThreshold)
    pp:SetBloomSoftKnee(v.bloomSoftKnee)
    pp:SetBloomClamp(v.bloomClamp)
    pp:SetBloomDiffusion(v.bloomDiffusion)
    pp:SetBloomTint(v.bloomTintR, v.bloomTintG, v.bloomTintB)

    pp:SetColorGradingEnabled(v.colorGradingEnabled)
    pp:SetExposure(v.exposure)
    pp:SetContrast(v.contrast)
    pp:SetSaturation(v.saturation)
    pp:SetTemperature(v.temperature)
    pp:SetColorGradingTint(v.colorGradingTint)
    pp:SetToneMapper(v.toneMapper)
    pp:SetColorFilter(v.colorFilterR, v.colorFilterG, v.colorFilterB)
    pp:SetGamma(v.gamma)

    pp:SetVignetteEnabled(v.vignetteEnabled)
    pp:SetVignetteIntensity(v.vignetteIntensity)
    pp:SetVignetteSmoothness(v.vignetteSmoothness)
    pp:SetVignetteRoundness(v.vignetteRoundness)
    pp:SetVignetteColor(v.vignetteColorR, v.vignetteColorG, v.vignetteColorB, v.vignetteColorA)

    pp:SetCAEnabled(v.caEnabled)
    pp:SetCAIntensity(v.caIntensity)

    pp:SetDistortionEnabled(v.distortionEnabled)
    pp:SetDistortionIntensity(v.distortionIntensity)

    pp:SetDoFEnabled(v.dofEnabled)
    pp:SetDoFDistance(v.dofDistance)
    pp:SetDoFRange(v.dofRange)
    pp:SetDoFStrength(v.dofStrength)
    pp:SetDoFTiltShift(v.dofTiltShift)
    pp:SetDoFFarTint(v.dofFarTintR, v.dofFarTintG, v.dofFarTintB)
    pp:SetDoFTintIntensity(v.dofTintIntensity)

    pp:SetAutoExposureEnabled(v.autoExposureEnabled)
    pp:SetAutoExposureMin(v.autoExposureMin)
    pp:SetAutoExposureMax(v.autoExposureMax)
    pp:SetAutoExposureSpeed(v.autoExposureSpeed)

    pp:SetGrainEnabled(v.grainEnabled)
    pp:SetGrainIntensity(v.grainIntensity)
    pp:SetGrainSize(v.grainSize)

    pp:SetBlurEnabled(v.blurEnabled)
    pp:SetBlurIntensity(v.blurIntensity)
    pp:SetBlurSpread(v.blurSpread)

    pp:SetRadialBlurEnabled(v.radialBlurEnabled)
    pp:SetRadialBlurIntensity(v.radialBlurIntensity)
    pp:SetRadialBlurCenter(v.radialBlurCenterX, v.radialBlurCenterY)

    pp:SetSharpenEnabled(v.sharpenEnabled)
    pp:SetSharpenIntensity(v.sharpenIntensity)

    pp:SetFogEnabled(v.fogEnabled)
    pp:SetFogMode(v.fogMode)
    pp:SetFogColor(v.fogColorR, v.fogColorG, v.fogColorB)
    pp:SetFogDensity(v.fogDensity)
    pp:SetFogStart(v.fogStart)
    pp:SetFogEnd(v.fogEnd)
    pp:SetFogHeightFalloff(v.fogHeightFalloff)
    pp:SetFogUseHeight(v.fogUseHeight)
    pp:SetFogHeightStart(v.fogHeightStart)
end

function Start(self)

end

function Update(self, dt)

end

function OnTriggerEnter(self, other)
    if insideZone then return end
    if other:CompareTag(TRIGGER_TAG) then
        insideZone = true
        ApplyValues(zone)
        Engine.Log("[PostProcessingZone] Enter -> valores de zona aplicados")
    end
end

function OnTriggerExit(self, other)
    if not insideZone then return end
    if other:CompareTag(TRIGGER_TAG) then
        insideZone = false
        ApplyValues(default)
        Engine.Log("[PostProcessingZone] Exit -> valores por defecto restaurados")
    end
end