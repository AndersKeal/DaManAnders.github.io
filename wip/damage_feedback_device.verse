using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Playspaces }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/Simulation }
using { /Verse.org/Colors }

# ----------------------------------------------------------------------------
# Damage feedback for a 12v12 game:
#   1) A full-screen "splash" flash whenever you take damage.
#   2) A directional marker that appears around the screen edge, pointing
#      toward whatever damaged you.
#
# This stub compiles with NO assets (it uses flat color_blocks). Once it works,
# swap the color_blocks for texture_blocks using your custom splash/arrow art
# (see the "SWAP TO TEXTURE" notes below).
# ----------------------------------------------------------------------------

# Per-player widgets we keep alive across respawns (the HUD lives on player_ui,
# which persists even when the character is destroyed and respawned).
feedback_widgets := class:
    SplashBlock : color_block
    IndicatorBlock : color_block
    ScreenCanvas : canvas

damage_feedback_device := class(creative_device):

    # --- Splash (on-screen hit feedback) -----------------------------------
    @editable
    SplashColor : color = NamedColors.Red
    @editable
    SplashOpacity : float = 0.35   # peak opacity on hit (0..1)
    @editable
    SplashSeconds : float = 0.35   # time to fade back to invisible

    # --- Directional indicator ---------------------------------------------
    @editable
    IndicatorColor : color = NamedColors.Red
    @editable
    IndicatorSize : float = 48.0    # marker size in slate units
    @editable
    IndicatorRadius : float = 260.0 # distance from screen center
    @editable
    IndicatorSeconds : float = 1.20 # how long the marker stays up

    # Per-player widget storage.
    var PlayerWidgets : [player]feedback_widgets = map{}

    OnBegin<override>()<suspends> : void =
        # Hook everyone already here, plus anyone who joins later.
        for (Player : GetPlayspace().GetPlayers()):
            spawn { ManagePlayer(Player) }
        GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)

    OnPlayerAdded(Player : player) : void =
        spawn { ManagePlayer(Player) }

    # Builds the HUD once, then keeps the damage subscription fresh across
    # respawns (each respawn is a brand-new fort_character).
    ManagePlayer(Player : player)<suspends> : void =
        InitUI(Player)
        loop:
            if (FortChar := Player.GetFortCharacter[]):
                FortChar.DamagedEvent().Subscribe(OnPlayerDamaged)
                # Wait until this character dies, then loop to hook the next one.
                FortChar.EliminatedEvent().Await()
            Sleep(0.5)

    # Creates the splash + indicator widgets and adds them to the player's HUD.
    InitUI(Player : player) : void =
        if:
            PlayerUI := GetPlayerUI[Player]
            not PlayerWidgets[Player]   # only build once per player
        then:
            # SWAP TO TEXTURE: replace this color_block with
            #   texture_block{DefaultImage := YourSplashTexture}
            Splash := color_block:
                DefaultColor := SplashColor
                DefaultOpacity := 0.0
            Splash.SetVisibility(visibility.Visible)

            # SWAP TO TEXTURE: replace with texture_block + your arrow art.
            Indicator := color_block:
                DefaultColor := IndicatorColor
                DefaultOpacity := 1.0
            Indicator.SetDesiredSize(vector2{X := IndicatorSize, Y := IndicatorSize})
            Indicator.SetVisibility(visibility.Collapsed)

            ScreenCanvas := canvas:
                Slots := array:
                    # Full-screen splash (stretches edge to edge).
                    canvas_slot:
                        Widget := Splash
                        Anchors := anchors{Minimum := vector2{X := 0.0, Y := 0.0}, Maximum := vector2{X := 1.0, Y := 1.0}}
                        Offsets := margin{Left := 0.0, Top := 0.0, Right := 0.0, Bottom := 0.0}
                        ZOrder := 0
                    # Directional marker (re-positioned per hit).
                    canvas_slot:
                        Widget := Indicator
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                        Offsets := margin{Left := 0.0, Top := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        ZOrder := 1

            PlayerUI.AddWidget(ScreenCanvas)

            NewWidgets := feedback_widgets:
                SplashBlock := Splash
                IndicatorBlock := Indicator
                ScreenCanvas := ScreenCanvas
            set PlayerWidgets = ConcatenateMaps(PlayerWidgets, map{Player => NewWidgets})

    # Fired for every damage event on a hooked character. We derive the victim
    # from the damage Target, so one shared handler covers all players.
    OnPlayerDamaged(Result : damage_result) : void =
        if:
            Target := Result.Target?
            VictimChar := fort_character[Target]    # damageable -> fort_character
            VictimAgent := VictimChar.GetAgent[]
            Victim := player[VictimAgent]
            W := PlayerWidgets[Victim]
        then:
            spawn { FlashSplash(W) }
            if (AttackerLoc := GetAttackerLocation(Result)):
                ShowDirection(W, VictimChar, AttackerLoc)

    # Spike the splash opacity, then ease it back down to 0.
    FlashSplash(W : feedback_widgets)<suspends> : void =
        Steps := 8
        var Cur : float = SplashOpacity
        W.SplashBlock.SetOpacity(Cur)
        StepAmt := SplashOpacity / Steps
        StepTime := SplashSeconds / Steps
        loop:
            Sleep(StepTime)
            set Cur -= StepAmt
            if (Cur <= 0.0):
                W.SplashBlock.SetOpacity(0.0)
                break
            W.SplashBlock.SetOpacity(Cur)

    # Place the marker on a ring around screen center in the attacker's
    # direction, relative to where the victim is currently looking.
    ShowDirection(W : feedback_widgets, VictimChar : fort_character, AttackerLoc : vector3) : void =
        VictimLoc := VictimChar.GetViewLocation()
        ViewRot := VictimChar.GetViewRotation()
        Forward := Flatten2D(ViewRot.GetLocalForward())
        Right := Flatten2D(ViewRot.GetLocalRight())
        ToAttacker := Normalize2D(AttackerLoc - VictimLoc)
        Along := DotProduct(ToAttacker, Forward)   # +front / -behind
        Side := DotProduct(ToAttacker, Right)      # +right / -left
        OffsetX := Side * IndicatorRadius
        OffsetY := -Along * IndicatorRadius        # screen Y grows downward
        PositionIndicator(W, OffsetX, OffsetY)
        spawn { HideIndicatorAfter(W) }

    PositionIndicator(W : feedback_widgets, OffsetX : float, OffsetY : float) : void =
        W.ScreenCanvas.RemoveWidget(W.IndicatorBlock)
        W.ScreenCanvas.AddWidget(canvas_slot:
            Widget := W.IndicatorBlock
            Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
            Offsets := margin{Left := OffsetX, Top := OffsetY, Right := 0.0, Bottom := 0.0}
            Alignment := vector2{X := 0.5, Y := 0.5}
            SizeToContent := true
            ZOrder := 1
        )
        W.IndicatorBlock.SetVisibility(visibility.Visible)

    HideIndicatorAfter(W : feedback_widgets)<suspends> : void =
        Sleep(IndicatorSeconds)
        W.IndicatorBlock.SetVisibility(visibility.Collapsed)

    # ------------------------------------------------------------------------
    # VERIFY THIS AGAINST YOUR INSTALLED VERSE DIGEST.
    # The shape of damage_result's instigator is the one field most likely to
    # differ between Verse versions. If this doesn't compile, fix it here only:
    # the splash will still work even if this always returns false (no marker).
    # ------------------------------------------------------------------------
    GetAttackerLocation(Result : damage_result)<transacts> : ?vector3 =
        if:
            Instigator := Result.Instigator?           # may be named differently
            AttackerChar := Instigator.GetFortCharacter[]
        then:
            option{ AttackerChar.GetTransform().Translation }
        else:
            false   # storm / fall damage / unknown source -> splash only

    # --- small vector helpers (2D, on the XY ground plane) ------------------
    Flatten2D(V : vector3) : vector3 =
        vector3{X := V.X, Y := V.Y, Z := 0.0}

    Normalize2D(V : vector3) : vector3 =
        Len := Sqrt((V.X * V.X) + (V.Y * V.Y))
        if (Len > 0.0):
            vector3{X := V.X / Len, Y := V.Y / Len, Z := 0.0}
        else:
            vector3{X := 0.0, Y := 0.0, Z := 0.0}
