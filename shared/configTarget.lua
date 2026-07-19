ConfigTarget = {
    -- Temporary ox_target option shown after choosing "Object Target".
    TargetLabel = 'Use object for scenario',
    TargetIcon = 'fa-solid fa-crosshairs',
    TargetDistance = 2.5,

    -- Object-local starting position. X is left/right, Y is forward/backward.
    DefaultOffset = { x = 0.0, y = 0.0, z = 0.5, heading = 180.0 },
    FineTuneStep = 0.025,
    FineTuneStepMin = 0.005,
    FineTuneStepMax = 0.25,
    FineTuneSliderStep = 0.005,
    -- Converts the movement slider value to degrees (0.025 x 200 = 5 degrees).
    RotationStepMultiplier = 200.0,
    CameraControl = 0xF84FA74F, -- Right mouse button in RedM
    CameraLookX = 0xA987235F,
    CameraLookY = 0xD2047988,
    CameraLookAtHeight = 0.75,
    CameraFov = 50.0,
    CameraOrbitSensitivity = 4.0,
    CameraHoldDetectionTimeout = 5000,
    CameraMinPitch = -60.0,
    CameraMaxPitch = 75.0,
    CameraZoomMin = 0.75,
    CameraZoomMax = 8.0,
    CameraZoomStep = 0.25,
    CameraTransition = 250,
    MaxOffset = 6.0,

    -- Saved inside this resource by server/target.lua.
    CacheFile = 'object_offsets.json',
}
