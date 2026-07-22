ConfigTarget = {
    -- Permanent ox_target entry used to open an object's shared pose library.
    TargetLabel = 'Object poses',
    TargetIcon = 'fa-solid fa-person',
    TargetDistance = 2.5,

    -- Jobs listed here may toggle Mod and manage hidden poses/unused coords, on or off duty.
    AdminJobs = {
        "admin",
        "actionsMod",
    },

    -- Jobs allowed to use Batch Upload Review, separate from AdminJobs.
    ReviewJobs = {
        "admin",
    },

    -- Object-local starting position. X is left/right, Y is forward/backward.
    DefaultOffset = { x = 0.0, y = 0.0, z = 0.5, heading = 180.0 },

    -- Object pose-list and footer text.
    MenuText = {
        ObjectTitle = 'Object Poses',
        AddPose = 'Add Pose',
        AddGroupTitle = 'Add Pose Group',
        Modify = 'Modify',
        Leave = 'Leave Pose',
        Exit = 'Exit',
        Undo = 'Undo',
        UndoTitle = 'Hidden Poses',
        NoHiddenPoses = 'No hidden poses',
        Empty = 'No poses added to this object',
        AllGroupsAdded = 'All poses are already added',
        AllGroupPosesAdded = 'All poses in this group are already added',
    },

    -- Defaults used whenever the Add/Modify Pose editor opens.
    PoseEditor = {
        AddTitle = 'Add pose',
        ModifyTitle = 'Modify point',
        DefaultStep = 0.025,
        DefaultCameraZoom = 2.5,
    },

    FineTuneStepMin = 0.005,
    FineTuneStepMax = 0.25,
    FineTuneSliderStep = 0.005,
    AddPoseMenuDelay = 5000, -- Prevent L from reopening the pose list during the editor transition.
    PropCleanupDelay = 250, -- Second attached-prop cleanup after the scenario task ends.
    ExitCollisionRadius = 0.3,
    ExitSafeCoordTolerance = 0.75,
    PointSearchDistance = 0.5,
    PointSearchDelay = 3000, -- Wait for the pose to settle before checking player coords.
    PointScanInterval = 350, -- Rescan after the editor moves the player.
    PointScanMoveThreshold = 0.1,
    PointScanLimit = 16,
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

    -- Shared object pose libraries are saved inside this resource.
    CacheFile = 'object_offsets.json',

    BatchReview = {
        File = 'object_offsets review.json',
        SpawnDistance = 2.5,
        ModelLoadTimeout = 10000,
        SessionTimeout = 1800000,
        CameraDistance = 3.0,
        CameraZoomMin = 0.75,
        CameraZoomMax = 8.0,
        CameraZoomStep = 0.25,
    },
}
