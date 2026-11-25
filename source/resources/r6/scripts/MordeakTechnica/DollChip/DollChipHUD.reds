module MordeakTechnica

@if(ModuleExists("NegotiableAffection"))
import NegotiableAffection.*

@if(ModuleExists("NegotiableAffection"))
public func IsNegotiableAffectionAvailable() -> Bool = true

@if(!ModuleExists("NegotiableAffection"))
public func IsNegotiableAffectionAvailable() -> Bool = false

@if(ModuleExists("NegotiableAffection"))
public func MordeakGetNABaseRisk(game: GameInstance) -> Int32 {
  let tunables = NA_Tunables.GetInstance(game);
  return IsDefined(tunables) ? tunables.GetGlobalRisk() : -1;
}

@if(!ModuleExists("NegotiableAffection"))
public func MordeakGetNABaseRisk(game: GameInstance) -> Int32 {
  return -1;
}

public class MordeakHUDOpenCallback extends DelayCallback {
  public let m_hudSystem: wref<MordeakCyberwareHUDSystem>;
  public let m_player: wref<PlayerPuppet>;
  public let m_generation: Int32;

  public func Call() -> Void {
    if IsDefined(this.m_hudSystem) {
      this.m_hudSystem.DelayedOpen(this.m_player, this.m_generation);
    }
  }
}

public class MordeakHUDDialogueCheckCallback extends DelayCallback {
  public let m_hudSystem: wref<MordeakCyberwareHUDSystem>;
  public let m_player: wref<PlayerPuppet>;
  public let m_generation: Int32;

  public func Call() -> Void {
    if IsDefined(this.m_hudSystem) {
      this.m_hudSystem.CheckDialogue(this.m_player, this.m_generation);
    }
  }
}

public class MordeakHUDPreview {
  public let m_background: wref<inkRectangle>;
  public let m_themeRectangles: array<wref<inkRectangle>>;
  public let m_themeRectangleAlphas: array<Float>;
  public let m_themeTexts: array<wref<inkText>>;
  public let m_themeTextAlphas: array<Float>;
  public let m_sicknessAccent: wref<inkRectangle>;
  public let m_sicknessValue: wref<inkText>;
  public let m_sicknessCount: wref<inkText>;

  public func Update(colorIndex: Int32, backgroundColorIndex: Int32, opacity: Int32) -> Void {
    if IsDefined(this.m_background) {
      this.m_background.SetTintColor(MordeakCyberwareHUDSystem.GetBackgroundColorForIndex(backgroundColorIndex));
      this.m_background.SetOpacity(ClampF(Cast<Float>(opacity) / 100.0, 0.0, 1.0));
    }

    let i: Int32 = 0;
    while i < ArraySize(this.m_themeRectangles) {
      if IsDefined(this.m_themeRectangles[i]) {
        this.m_themeRectangles[i].SetTintColor(MordeakCyberwareHUDSystem.GetAccentColorForIndex(colorIndex, this.m_themeRectangleAlphas[i]));
      }
      i += 1;
    }
    i = 0;
    while i < ArraySize(this.m_themeTexts) {
      if IsDefined(this.m_themeTexts[i]) {
        this.m_themeTexts[i].SetTintColor(MordeakCyberwareHUDSystem.GetAccentColorForIndex(colorIndex, this.m_themeTextAlphas[i]));
      }
      i += 1;
    }
    let accent: HDRColor = MordeakCyberwareHUDSystem.GetAccentColorForIndex(colorIndex, 1.0);
    if IsDefined(this.m_sicknessAccent) {
      this.m_sicknessAccent.SetTintColor(accent);
    }
    if IsDefined(this.m_sicknessValue) {
      this.m_sicknessValue.SetTintColor(accent);
    }
    if IsDefined(this.m_sicknessCount) {
      this.m_sicknessCount.SetTintColor(accent);
    }
  }
}

// Owns the HUD widgets and keeps their contents synchronized with player state.
public class MordeakCyberwareHUDSystem extends ScriptableSystem {
  private let m_canvas: wref<inkCanvas>;
  private let m_statusBadge: wref<inkText>;
  private let m_statusBackground: wref<inkRectangle>;
  private let m_mainBackground: wref<inkRectangle>;
  private let m_specsLeft: wref<inkText>;
  private let m_specsRight: wref<inkText>;
  private let m_itemValues: array<wref<inkText>>;
  private let m_itemAccents: array<wref<inkRectangle>>;
  private let m_telemetryValues: array<wref<inkText>>;
  private let m_telemetryDetails: array<wref<inkText>>;
  private let m_telemetryBars: array<wref<inkRectangle>>;
  private let m_sicknessValue: wref<inkText>;
  private let m_sicknessCount: wref<inkText>;
  private let m_sicknessAccent: wref<inkRectangle>;
  private let m_themeRectangles: array<wref<inkRectangle>>;
  private let m_themeRectangleAlphas: array<Float>;
  private let m_themeTexts: array<wref<inkText>>;
  private let m_themeTextAlphas: array<Float>;
  private let m_sicknessOverlay: array<wref<inkRectangle>>;
  private let m_logWidget: wref<inkText>;
  private let m_isOpen: Bool;
  private let m_combatBlackboard: ref<IBlackboard>;
  private let m_combatListener: ref<CallbackHandle>;
  private let m_backgroundOpacity: Float;
  private let m_delayedOpenPending: Bool;
  private let m_delayedOpenGeneration: Int32;

  // Retrieve the single HUD system instance managed by the game.
  public static func GetInstance(game: GameInstance) -> ref<MordeakCyberwareHUDSystem> {
    return game.GetScriptableSystemsContainer().Get(n"MordeakTechnica.MordeakCyberwareHUDSystem") as MordeakCyberwareHUDSystem;
  }

  private func OnAttach() -> Void {
    GameInstance.GetCallbackSystem()
      .RegisterCallback(n"Session/Ready", this, n"OnSessionReady")
      .SetLifetime(CallbackLifetime.Forever);
  }

  // Start combat and settings listeners when the game session becomes ready.
  private cb func OnSessionReady(event: ref<GameSessionEvent>) -> Void {
    this.Hide();
    this.UnregisterCombatListener();
    this.RegisterCombatListener();

    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    if !IsDefined(questsSystem) {
      return;
    }

    questsSystem.RegisterListener(n"mordeak_dollchip_hud_color", this, n"OnHudColorChanged");
    questsSystem.RegisterListener(n"mordeak_dollchip_hud_background_color", this, n"OnHudBackgroundColorChanged");
    questsSystem.RegisterListener(n"mordeak_dollchip_hud_opacity", this, n"OnHudOpacityChanged");
    this.OnHudBackgroundColorChanged(questsSystem.GetFact(n"mordeak_dollchip_hud_background_color"));
    this.OnHudOpacityChanged(questsSystem.GetFact(n"mordeak_dollchip_hud_opacity"));
    if IsNegotiableAffectionAvailable() {
      questsSystem.RegisterListener(n"na_sick", this, n"OnSicknessChanged");
      questsSystem.RegisterListener(n"na_sick_count", this, n"OnSicknessChanged");
      questsSystem.RegisterListener(n"na_f2find", this, n"OnSicknessChanged");
      questsSystem.RegisterListener(n"na_rawdog_tier", this, n"OnSicknessChanged");
      questsSystem.RegisterListener(n"na_velvettouch_tier", this, n"OnSicknessChanged");
      questsSystem.RegisterListener(n"na_smoothskin_tier", this, n"OnSicknessChanged");
      questsSystem.RegisterListener(n"na_neverlock_tier", this, n"OnSicknessChanged");
    }
  }

  public cb func OnHudColorChanged(value: Int32) -> Bool {
    this.RefreshCurrentPlayer();
    return true;
  }

  private func RefreshCurrentPlayer() -> Void {
    let playerSystem = GameInstance.GetPlayerSystem(this.GetGameInstance());
    if IsDefined(playerSystem) {
      let player: ref<PlayerPuppet> = playerSystem.GetLocalPlayerControlledGameObject() as PlayerPuppet;
      this.Refresh(player);
    }
  }

  public cb func OnHudOpacityChanged(value: Int32) -> Bool {
    let opacity: Float = 1.0;
    if value >= 1 && value <= 101 {
      opacity = Cast<Float>(value - 1) / 100.0;
    }
    this.m_backgroundOpacity = opacity;
    this.UpdateBackgroundOpacity();
    return true;
  }

  public cb func OnHudBackgroundColorChanged(value: Int32) -> Bool {
    if IsDefined(this.m_mainBackground) {
      this.m_mainBackground.SetTintColor(MordeakCyberwareHUDSystem.GetBackgroundColorForIndex(value));
    }
    if this.m_isOpen {
      this.RefreshCurrentPlayer();
    }
    return true;
  }

  // Hide the popup immediately when combat starts.
  private func RegisterCombatListener() -> Void {
    let game: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(game).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return;
    }

    this.m_combatBlackboard = GameInstance.GetBlackboardSystem(game)
      .GetLocalInstanced(player.GetEntityID(), GetAllBlackboardDefs().PlayerStateMachine);
    if !IsDefined(this.m_combatBlackboard) {
      return;
    }

    this.m_combatListener = this.m_combatBlackboard.RegisterListenerInt(
      GetAllBlackboardDefs().PlayerStateMachine.Combat,
      this,
      n"OnCombatStateChanged"
    );

    if player.IsInCombat() {
      this.Hide();
    }
  }

  private func UnregisterCombatListener() -> Void {
    if IsDefined(this.m_combatBlackboard) && IsDefined(this.m_combatListener) {
      this.m_combatBlackboard.UnregisterListenerInt(
        GetAllBlackboardDefs().PlayerStateMachine.Combat,
        this.m_combatListener
      );
    }
    this.m_combatBlackboard = null;
    this.m_combatListener = null;
  }

  // Keep the popup closed during combat.
  public cb func OnCombatStateChanged(value: Int32) -> Bool {
    if Equals(IntEnum<gamePSMCombat>(value), gamePSMCombat.InCombat) {
      this.Hide();
    }
    return true;
  }

  // Refresh infection data when its quest facts change.
  public cb func OnSicknessChanged(value: Int32) -> Bool {
    let playerSystem = GameInstance.GetPlayerSystem(this.GetGameInstance());
    if IsDefined(playerSystem) {
      let player: ref<PlayerPuppet> = playerSystem.GetLocalPlayerControlledGameObject() as PlayerPuppet;
      this.Refresh(player);
    }
    return true;
  }

  // Keep widget references so future updates can change them without rebuilding.
  public func RegisterWidgets(
    canvas: ref<inkCanvas>,
    statusBadge: ref<inkText>,
    statusBackground: ref<inkRectangle>,
    specsLeft: ref<inkText>,
    specsRight: ref<inkText>,
    itemValues: array<wref<inkText>>,
    itemAccents: array<wref<inkRectangle>>,
    telemetryValues: array<wref<inkText>>,
    telemetryDetails: array<wref<inkText>>,
    telemetryBars: array<wref<inkRectangle>>,
    sicknessValue: ref<inkText>,
    sicknessCount: ref<inkText>,
    sicknessAccent: ref<inkRectangle>,
    themeRectangles: array<wref<inkRectangle>>,
    themeRectangleAlphas: array<Float>,
    themeTexts: array<wref<inkText>>,
    themeTextAlphas: array<Float>,
    sicknessOverlay: array<wref<inkRectangle>>,
    logWidget: ref<inkText>,
    game: GameInstance
  ) -> Void {
    this.m_canvas = canvas;
    this.m_statusBadge = statusBadge;
    this.m_statusBackground = statusBackground;
    this.m_specsLeft = specsLeft;
    this.m_specsRight = specsRight;
    this.m_itemValues = itemValues;
    this.m_itemAccents = itemAccents;
    this.m_telemetryValues = telemetryValues;
    this.m_telemetryDetails = telemetryDetails;
    this.m_telemetryBars = telemetryBars;
    this.m_sicknessValue = sicknessValue;
    this.m_sicknessCount = sicknessCount;
    this.m_sicknessAccent = sicknessAccent;
    this.m_themeRectangles = themeRectangles;
    this.m_themeRectangleAlphas = themeRectangleAlphas;
    this.m_themeTexts = themeTexts;
    this.m_themeTextAlphas = themeTextAlphas;
    this.m_sicknessOverlay = sicknessOverlay;
    this.m_logWidget = logWidget;

    if this.m_isOpen {
      let playerSystem = GameInstance.GetPlayerSystem(game);
      if IsDefined(playerSystem) {
        let player: ref<PlayerPuppet> = playerSystem.GetLocalPlayerControlledGameObject() as PlayerPuppet;
        this.Refresh(player);
      }
    }
  }

  private static func IsDialogueActive(player: ref<PlayerPuppet>) -> Bool {
    let game: GameInstance = player.GetGame();
    let sceneSystem: ref<SceneSystem> = GameInstance.GetSceneSystem(game);
    let blackboardSystem = GameInstance.GetBlackboardSystem(game);
    if !IsDefined(sceneSystem) || !IsDefined(blackboardSystem) {
      FTLog("[MordeakTechnica] Cannot check dialogue state: game systems are unavailable.");
      return true;
    }

    let sceneInterface: ref<SceneSystemInterface> = sceneSystem.GetScriptInterface();
    let interactions: ref<IBlackboard> = blackboardSystem.Get(GetAllBlackboardDefs().UIInteractions);
    if !IsDefined(sceneInterface) || !IsDefined(interactions) {
      FTLog("[MordeakTechnica] Cannot check dialogue state: scene or interaction data is unavailable.");
      return true;
    }

    if sceneInterface.IsEntityInDialogue(player.GetEntityID()) {
      return true;
    }

    let hubs: DialogChoiceHubs = FromVariant<DialogChoiceHubs>(
      interactions.GetVariant(GetAllBlackboardDefs().UIInteractions.DialogChoiceHubs)
    );
    if ArraySize(hubs.choiceHubs) > 0 {
      return true;
    }

    if IsNegotiableAffectionAvailable() {
      let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
      if !IsDefined(questsSystem) {
        FTLog("[MordeakTechnica] Cannot check Negotiable Affection dialogue: quest data is unavailable.");
        return true;
      }
      if questsSystem.GetFact(n"na_dialogue_choice_trigger") > 0 {
        return true;
      }
    }
    return false;
  }

  private func ScheduleDialogueCheck(player: ref<PlayerPuppet>, generation: Int32) -> Void {
    let callback: ref<MordeakHUDDialogueCheckCallback> = new MordeakHUDDialogueCheckCallback();
    callback.m_hudSystem = this;
    callback.m_player = player;
    callback.m_generation = generation;
    GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(callback, 0.2, false);
  }

  public func CheckDialogue(player: ref<PlayerPuppet>, generation: Int32) -> Void {
    if generation != this.m_delayedOpenGeneration || (!this.m_isOpen && !this.m_delayedOpenPending) {
      return;
    }
    if !IsDefined(player) {
      this.Hide();
      return;
    }
    if MordeakCyberwareHUDSystem.IsDialogueActive(player) {
      this.Hide();
      return;
    }
    this.ScheduleDialogueCheck(player, generation);
  }

  // Open only when the player has DollChip equipped and is out of combat and dialogue.
  public static func Open(player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) {
      return false;
    }

    if DollChipFact.GetTier(player) <= 0 {
      FTLog("[MordeakTechnica] PlayMate HUD requires PlayMate cyberware to be equipped.");
      return false;
    }

    if player.IsInCombat() || MordeakCyberwareHUDSystem.IsDialogueActive(player) {
      return false;
    }

    let hudSystem: ref<MordeakCyberwareHUDSystem> = MordeakCyberwareHUDSystem.GetInstance(player.GetGame());
    if !IsDefined(hudSystem) {
      FTLog("[MordeakTechnica] PlayMate HUD system is unavailable.");
      return false;
    }

    if !IsDefined(hudSystem.m_canvas) && !MordeakCyberwareHUDSystem.EnsureWidgets(player.GetGame()) {
      FTLog("[MordeakTechnica] PlayMate HUD popup could not be created.");
      return false;
    }

    let sicknessCount: Int32 = MordeakCyberwareHUDSystem.GetSicknessCount(player.GetGame());
    if sicknessCount == 6 || sicknessCount == 12 {
      if !hudSystem.m_delayedOpenPending {
        hudSystem.m_delayedOpenPending = true;
        hudSystem.m_delayedOpenGeneration += 1;
        let callback: ref<MordeakHUDOpenCallback> = new MordeakHUDOpenCallback();
        callback.m_hudSystem = hudSystem;
        callback.m_player = player;
        callback.m_generation = hudSystem.m_delayedOpenGeneration;
        GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(callback, 8.0, false);
        hudSystem.ScheduleDialogueCheck(player, hudSystem.m_delayedOpenGeneration);
      }
      return true;
    }

    hudSystem.m_delayedOpenPending = false;
    hudSystem.m_delayedOpenGeneration += 1;
    hudSystem.m_isOpen = true;
    hudSystem.Refresh(player);
    if hudSystem.m_isOpen {
      hudSystem.ScheduleDialogueCheck(player, hudSystem.m_delayedOpenGeneration);
    }
    return true;
  }

  // Hide the HUD if its system instance is available.
  public static func Close(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) {
      return;
    }

    let hudSystem: ref<MordeakCyberwareHUDSystem> = MordeakCyberwareHUDSystem.GetInstance(player.GetGame());
    if IsDefined(hudSystem) {
      hudSystem.Hide();
    }
  }

  // Callback triggered after 8-second delay for 30% and 60% infection rates.
  public func DelayedOpen(player: ref<PlayerPuppet>, generation: Int32) -> Void {
    if !this.m_delayedOpenPending || generation != this.m_delayedOpenGeneration {
      return;
    }

    this.m_delayedOpenPending = false;
    if !IsDefined(player) {
      return;
    }

    this.m_isOpen = true;
    this.Refresh(player);
  }

  // Toggle visibility; opening still goes through the equipment, combat, and dialogue checks.
  public static func Toggle(player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) {
      return false;
    }

    let hudSystem: ref<MordeakCyberwareHUDSystem> = MordeakCyberwareHUDSystem.GetInstance(player.GetGame());
    if !IsDefined(hudSystem) {
      FTLog("[MordeakTechnica] PlayMate HUD system is unavailable.");
      return false;
    }

    if hudSystem.m_isOpen || hudSystem.m_delayedOpenPending {
      hudSystem.Hide();
      return false;
    }

    return MordeakCyberwareHUDSystem.Open(player);
  }

  // Refresh the singleton HUD for external callers such as equipment changes.
  public static func RefreshForPlayer(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) {
      return;
    }

    let hudSystem: ref<MordeakCyberwareHUDSystem> = MordeakCyberwareHUDSystem.GetInstance(player.GetGame());
    if IsDefined(hudSystem) {
      hudSystem.Refresh(player);
    }
  }

  // Set the background opacity (0.0 to 1.0).
  public static func SetBackgroundOpacity(game: GameInstance, opacity: Float) -> Void {
    let hudSystem: ref<MordeakCyberwareHUDSystem> = MordeakCyberwareHUDSystem.GetInstance(game);
    if IsDefined(hudSystem) {
      hudSystem.m_backgroundOpacity = ClampF(opacity, 0.0, 1.0);
      hudSystem.UpdateBackgroundOpacity();
    }
  }

  // Get the current background opacity setting.
  public static func GetBackgroundOpacity(game: GameInstance) -> Float {
    let hudSystem: ref<MordeakCyberwareHUDSystem> = MordeakCyberwareHUDSystem.GetInstance(game);
    if IsDefined(hudSystem) {
      return hudSystem.m_backgroundOpacity;
    }
    return 1.0;
  }

  // Rebuild visible values and colors from the current cyberware and quest facts.
  public func Refresh(player: ref<PlayerPuppet>) -> Void {
    if !this.m_isOpen {
      return;
    }

    if !IsDefined(player) {
      return;
    }

    if player.IsInCombat() || MordeakCyberwareHUDSystem.IsDialogueActive(player) {
      this.Hide();
      return;
    }

    if DollChipFact.GetTier(player) <= 0 {
      this.Hide();
      return;
    }

    if !IsDefined(this.m_canvas)
      || !IsDefined(this.m_statusBadge)
      || !IsDefined(this.m_statusBackground)
      || !IsDefined(this.m_specsLeft)
      || !IsDefined(this.m_specsRight)
      || !IsDefined(this.m_sicknessValue)
      || !IsDefined(this.m_sicknessCount)
      || !IsDefined(this.m_sicknessAccent)
      || !IsDefined(this.m_logWidget)
      || ArraySize(this.m_itemValues) != 5
      || ArraySize(this.m_itemAccents) != 5
      || ArraySize(this.m_telemetryValues) != 5
      || ArraySize(this.m_telemetryDetails) != 5
      || ArraySize(this.m_telemetryBars) != 5 {
      return;
    }

    // Collect installed tiers in the same order used by the HUD rows.
    let tiers: array<Int32>;
    ArrayPush(tiers, RawDogFact.GetTier(player));
    ArrayPush(tiers, VelvetTouchFact.GetTier(player));
    ArrayPush(tiers, SmoothSkinFact.GetTier(player));
    ArrayPush(tiers, NeverLockFact.GetTier(player));
    ArrayPush(tiers, DollChipFact.GetTier(player));

    let fittedCount: Int32 = 0;
    let itemIndex: Int32 = 0;
    while itemIndex < ArraySize(tiers) {
      if tiers[itemIndex] > 0 {
        fittedCount += 1;
      }

      this.m_itemValues[itemIndex].SetText(MordeakCyberwareHUDSystem.FormatTier(tiers[itemIndex]));
      let itemColor: HDRColor = MordeakCyberwareHUDSystem.GetTierColor(tiers[itemIndex]);
      this.m_itemValues[itemIndex].SetTintColor(itemColor);
      this.m_itemAccents[itemIndex].SetTintColor(itemColor);
      itemIndex += 1;
    }
    this.UpdateTelemetry(player.GetGame());

    // Show the warning badge only when the infection fact is active.
    let sicknessStatus: String = MordeakCyberwareHUDSystem.GetSicknessStatus(player.GetGame());
    let sicknessCount: Int32 = MordeakCyberwareHUDSystem.GetSicknessCount(player.GetGame());
    let confidenceRate: String = MordeakCyberwareHUDSystem.FormatConfidenceRate(sicknessCount);
    let themeColor: HDRColor = MordeakCyberwareHUDSystem.GetAccentColor(player.GetGame(), 1.0);
    let themeBackgroundColor: HDRColor = MordeakCyberwareHUDSystem.GetAccentColor(player.GetGame(), 0.16);
    this.UpdateSicknessOverlay(sicknessCount, player.GetGame());
    let infectionDetected: Bool = Equals(sicknessStatus, "AT RISK");
    let statusColor: HDRColor = themeColor;
    let statusBackgroundColor: HDRColor = themeBackgroundColor;
    let badgeText: String = "";
    if infectionDetected {
      statusColor = MordeakCyberwareHUDSystem.GetTraumaAlertColor(player.GetGame(), 1.0);
      statusBackgroundColor = MordeakCyberwareHUDSystem.GetTraumaAlertColor(player.GetGame(), 0.2);
      badgeText = "TRAUMA ALERT";
    } else {
      if !Equals(sicknessStatus, "CLEAN") {
        statusColor = HDRColor(1.0, 0.56, 0.08, 1.0);
        statusBackgroundColor = HDRColor(1.0, 0.56, 0.08, 0.16);
      }
    }

    this.m_statusBadge.SetText(badgeText);
    this.m_statusBadge.SetTintColor(statusColor);
    this.m_statusBadge.SetVisible(infectionDetected);
    this.m_statusBackground.SetTintColor(statusBackgroundColor);
    this.m_statusBackground.SetVisible(infectionDetected);
    let themeIndex: Int32 = 0;
    while themeIndex < ArraySize(this.m_themeRectangles) {
      this.m_themeRectangles[themeIndex].SetTintColor(
        MordeakCyberwareHUDSystem.GetAccentColor(
          player.GetGame(),
          this.m_themeRectangleAlphas[themeIndex]
        )
      );
      themeIndex += 1;
    }
    themeIndex = 0;
    while themeIndex < ArraySize(this.m_themeTexts) {
      this.m_themeTexts[themeIndex].SetTintColor(
        MordeakCyberwareHUDSystem.GetAccentColor(
          player.GetGame(),
          this.m_themeTextAlphas[themeIndex]
        )
      );
      themeIndex += 1;
    }
    this.m_specsLeft.SetText(
      "SUBJECT: V // PLAYMATE: " + MordeakCyberwareHUDSystem.FormatTier(tiers[4])
        + "\nMORDEAK UNITS: " + ToString(fittedCount) + " / 5"
    );
    this.m_specsRight.SetText(
      "NEURO-LINK: " + (IsNegotiableAffectionAvailable() ? "ONLINE" : "OFFLINE")
        + "\nINFECTION SEVERITY: " + confidenceRate
    );
    this.m_sicknessValue.SetText(sicknessStatus);
    this.m_sicknessValue.SetTintColor(statusColor);
    this.m_sicknessCount.SetText(confidenceRate);
    this.m_sicknessCount.SetTintColor(statusColor);
    this.m_sicknessAccent.SetTintColor(statusColor);
    this.m_logWidget.SetText(
      "[SYSTEM] PlayMate monitor online.\n[NEGOTIABLE AFFECTION] Sickness: "
        + sicknessStatus + " // Confidence: " + confidenceRate
    );
    this.m_canvas.SetVisible(true);
  }

  private func UpdateTelemetry(game: GameInstance) -> Void {
    let values: array<String>;
    let details: array<String>;
    let barValues: array<Float>;
    let qs: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);

    if IsNegotiableAffectionAvailable() && IsDefined(qs) {
      let rawTier: Int32 = qs.GetFact(n"na_rawdog_tier");
      let velvetTier: Int32 = qs.GetFact(n"na_velvettouch_tier");
      let smoothTier: Int32 = qs.GetFact(n"na_smoothskin_tier");
      let neverTier: Int32 = qs.GetFact(n"na_neverlock_tier");

      let rawBonus: Int32 = rawTier >= 11 ? 50 : rawTier * 4;
      let rawRisk: Int32 = Max(0, 50 - rawBonus);
      ArrayPush(values, ToString(rawRisk) + "%");
      ArrayPush(details, "RAW VS CARRIER | BASE 50%");
      ArrayPush(barValues, Cast<Float>(rawRisk) / 50.0);

      let tipShift: Int32 = velvetTier >= 11 ? 20 : velvetTier;
      ArrayPush(values, ToString(10 + tipShift) + "-" + ToString(30 + tipShift) + "%");
      ArrayPush(details, "BASE + VELVET | EXCL. CLIENT BONUS");
      ArrayPush(barValues, Cast<Float>(30 + tipShift) / 50.0);

      let smoothBonus: Int32 = smoothTier >= 11 ? 40 : smoothTier * 3;
      let failRisk: Int32 = Max(0, 40 - smoothBonus);
      let failEnabled: Bool = qs.GetFact(n"na_f2find") == 1;
      ArrayPush(values, failEnabled ? ToString(failRisk) + "%" : "DISABLED");
      ArrayPush(details, failEnabled ? "BASE 40% | SMOOTH SKIN" : "FAIL TO FIND DISABLED");
      ArrayPush(barValues, failEnabled ? Cast<Float>(failRisk) / 40.0 : 0.0);

      let neverBonus: Int32 = neverTier >= 11 ? 30 : neverTier * 2;
      let baseRisk: Int32 = MordeakGetNABaseRisk(game);
      let eventRisk: Int32 = Max(0, baseRisk - neverBonus);
      ArrayPush(values, baseRisk >= 0 ? ToString(eventRisk) + "%" : "UNAVAILABLE");
      ArrayPush(details, baseRisk >= 0
        ? "BASE " + ToString(baseRisk) + "% - NEVERLOCK ONLY"
        : "BASE SHIFT RISK UNAVAILABLE");
      ArrayPush(barValues, baseRisk >= 0 ? Cast<Float>(eventRisk) / 100.0 : 0.0);

      let payout: Int32 = (rawTier + velvetTier + smoothTier + neverTier) * 5;
      ArrayPush(values, "+" + ToString(payout) + "%");
      ArrayPush(details, "ALL JOYWARE TIERS | MAX +220%");
      ArrayPush(barValues, Cast<Float>(payout) / 220.0);
    } else {
      let offlineIndex: Int32 = 0;
      while offlineIndex < 5 {
        ArrayPush(values, IsNegotiableAffectionAvailable() ? "UNAVAILABLE" : "OFFLINE");
        ArrayPush(details, IsNegotiableAffectionAvailable() ? "QUEST DATA UNAVAILABLE" : "NEGOTIABLE AFFECTION OFFLINE");
        ArrayPush(barValues, 0.0);
        offlineIndex += 1;
      }
    }

    let i: Int32 = 0;
    while i < 5 {
      this.m_telemetryValues[i].SetText(values[i]);
      this.m_telemetryDetails[i].SetText(details[i]);
      this.m_telemetryBars[i].SetSize(Vector2(300.0 * ClampF(barValues[i], 0.0, 1.0), 4.0));
      i += 1;
    }
  }

  // Sickness overlay removed.
  private func UpdateSicknessOverlay(sicknessCount: Int32, game: GameInstance) -> Void {
  }

  // Update the background opacity from the current setting.
  private func UpdateBackgroundOpacity() -> Void {
    if IsDefined(this.m_mainBackground) {
      this.m_mainBackground.SetOpacity(this.m_backgroundOpacity);
    }
  }

  // Close the popup and reset its toggle state.
  public func Hide() -> Void {
    this.m_delayedOpenPending = false;
    this.m_delayedOpenGeneration += 1;
    this.m_isOpen = false;
    if IsDefined(this.m_canvas) {
      this.m_canvas.SetVisible(false);
    }
  }

  // Convert the cyberware tier index into its display label.
  private static func FormatTier(tier: Int32) -> String {
    if tier <= 0 {
      return "NOT INSTALLED";
    }

    let tierNames: array<String> = [
      "COMMON",
      "COMMON+",
      "UNCOMMON",
      "UNCOMMON+",
      "RARE",
      "RARE+",
      "EPIC",
      "EPIC+",
      "LEGENDARY",
      "LEGENDARY+",
      "LEGENDARY++"
    ];

    if tier > ArraySize(tierNames) {
      return "UNKNOWN";
    }

    return tierNames[tier - 1];
  }

  // Assign a rarity color to each cyberware tier.
  private static func GetTierColor(tier: Int32) -> HDRColor {
    if tier <= 0 {
      return HDRColor(0.35, 0.42, 0.54, 1.0);
    }

    if tier <= 2 {
      return HDRColor(0.86, 0.88, 0.92, 1.0);
    }

    if tier <= 4 {
      return HDRColor(0.20, 0.82, 0.25, 1.0);
    }

    if tier <= 6 {
      return HDRColor(0.12, 0.60, 1.0, 1.0);
    }

    if tier <= 8 {
      return HDRColor(0.72, 0.28, 1.0, 1.0);
    }

    return HDRColor(1.0, 0.58, 0.12, 1.0);
  }

  private static func GetTelemetryColor(index: Int32) -> HDRColor {
    if index == 0 { return HDRColor(0.72, 0.28, 1.0, 1.0); }
    if index == 1 { return HDRColor(1.0, 0.78, 0.08, 1.0); }
    if index == 2 { return HDRColor(0.08, 0.82, 0.95, 1.0); }
    if index == 3 { return HDRColor(0.95, 0.20, 0.30, 1.0); }
    return HDRColor(0.0, 0.95, 0.72, 1.0);
  }

  // Read the user's selected accent color, falling back to red.
  private static func GetAccentColor(game: GameInstance, alpha: Float) -> HDRColor {
    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    let colorIndex: Int32 = 1;
    if IsDefined(questsSystem) {
      colorIndex = questsSystem.GetFact(n"mordeak_dollchip_hud_color");
    }

    return MordeakCyberwareHUDSystem.GetAccentColorForIndex(colorIndex, alpha);
  }

  public static func GetAccentColorForIndex(colorIndex: Int32, alpha: Float) -> HDRColor {
    if colorIndex == 2 {
      return HDRColor(1.0, 0.78, 0.08, alpha);
    }
    if colorIndex == 3 {
      return HDRColor(0.08, 0.70, 1.0, alpha);
    }
    if colorIndex == 4 {
      return HDRColor(1.0, 0.24, 0.66, alpha);
    }
    if colorIndex == 5 {
      return HDRColor(0.0, 0.0, 0.0, alpha);
    }

    return HDRColor(1.0, 0.0, 0.24, alpha);
  }

  public static func GetBackgroundColorForIndex(colorIndex: Int32) -> HDRColor {
    if colorIndex >= 2 && colorIndex <= 6 {
      return MordeakCyberwareHUDSystem.GetAccentColorForIndex(colorIndex - 1, 1.0);
    }
    return HDRColor(0.0, 0.0, 0.0, 1.0);
  }

  private static func GetTraumaAlertColor(game: GameInstance, alpha: Float) -> HDRColor {
    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    if IsDefined(questsSystem) {
      let backgroundColorIndex: Int32 = questsSystem.GetFact(n"mordeak_dollchip_hud_background_color");
      if backgroundColorIndex == 2 || backgroundColorIndex == 5 {
        return HDRColor(1.0, 0.78, 0.08, alpha);
      }
    }
    return HDRColor(1.0, 0.0, 0.33, alpha);
  }

  // Read infection state from NegotiableAffection when that mod is installed.
  private static func GetSicknessStatus(game: GameInstance) -> String {
    if !IsNegotiableAffectionAvailable() {
      return "OFFLINE";
    }

    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    if !IsDefined(questsSystem) {
      return "UNAVAILABLE";
    }

    return questsSystem.GetFact(n"na_sick") > 0 ? "AT RISK" : "CLEAN";
  }

  // Return the infection counter, or -1 when its source is unavailable.
  private static func GetSicknessCount(game: GameInstance) -> Int32 {
    if !IsNegotiableAffectionAvailable() {
      return -1;
    }

    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    if !IsDefined(questsSystem) {
      return -1;
    }

    return questsSystem.GetFact(n"na_sick_count");
  }

  // Convert the infection counter to the percentage shown in the HUD.
  private static func FormatConfidenceRate(sicknessCount: Int32) -> String {
    if sicknessCount < 0 {
      return "--";
    }

    if sicknessCount == 0 {
      return "N/A";
    }

    if sicknessCount >= 20 {
      return "100%";
    }

    return ToString(sicknessCount * 5) + "%";
  }

  // Create and position a colored rectangle inside a parent canvas.
  public static func CreateRectangle(
    parent: ref<inkCanvas>,
    name: CName,
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    color: HDRColor
  ) -> ref<inkRectangle> {
    let widget = new inkRectangle();
    widget.SetName(name);
    widget.SetAnchor(inkEAnchor.TopLeft);
    widget.SetAnchorPoint(Vector2(0.0, 0.0));
    widget.SetSize(Vector2(width, height));
    widget.SetTranslation(Vector2(x, y));
    widget.SetTintColor(color);
    widget.Reparent(parent);
    return widget;
  }

  // Create and style a text widget inside a parent canvas.
  public static func CreateText(
    parent: ref<inkCanvas>,
    name: CName,
    text: String,
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    fontSize: Int32,
    color: HDRColor
  ) -> ref<inkText> {
    let widget = new inkText();
    widget.SetName(name);
    widget.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    widget.SetFontStyle(n"Medium");
    widget.SetFontSize(fontSize);
    widget.SetTintColor(color);
    widget.SetAnchor(inkEAnchor.TopLeft);
    widget.SetAnchorPoint(Vector2(0.0, 0.0));
    widget.SetSize(Vector2(width, height));
    widget.SetTranslation(Vector2(x, y));
    widget.SetVAlign(inkEVerticalAlign.Center);
    widget.SetText(text);
    widget.Reparent(parent);
    return widget;
  }

  // Create the popup canvas and all child widgets once the HUD layer is available.
  public static func EnsureWidgets(game: GameInstance) -> Bool {
    let inkSystem = GameInstance.GetInkSystem();
    if !IsDefined(inkSystem) {
      return false;
    }

    let layer = inkSystem.GetLayer(n"inkHUDLayer");
    if !IsDefined(layer) {
      return false;
    }

    let hudWindow = layer.GetVirtualWindow();
    if !IsDefined(hudWindow) {
      return false;
    }
    let hudSystem: ref<MordeakCyberwareHUDSystem> = MordeakCyberwareHUDSystem.GetInstance(game);
    if !IsDefined(hudSystem) {
      return false;
    }
    let existingCanvas = hudWindow.GetWidget(n"MordeakCyberwareHUDCanvas");
    if IsDefined(existingCanvas) {
      if IsDefined(hudSystem.m_canvas) {
        return true;
      }
      hudWindow.RemoveChild(existingCanvas);
    }

    let canvas = new inkCanvas();
    canvas.SetName(n"MordeakCyberwareHUDCanvas");
    canvas.SetSize(Vector2(1920.0, 1080.0));
    canvas.SetOpacity(1.0);
    canvas.SetAnchor(inkEAnchor.Fill);
    canvas.SetInteractive(false);
    canvas.SetVisible(false);
    canvas.Reparent(hudWindow);

    // Leave room above the popup for the health bar and status icons.
    let panel = new inkCanvas();
    panel.SetName(n"MordeakCyberwareHUDPanel");
    panel.SetSize(Vector2(760.0, 710.0));
    panel.SetAnchor(inkEAnchor.TopLeft);
    panel.SetAnchorPoint(Vector2(0.0, 0.0));
    panel.SetTranslation(Vector2(107.0, 190.0));
    panel.Reparent(canvas);

    MordeakCyberwareHUDSystem.BuildPanel(canvas, panel, game, hudSystem, null);
    return true;
  }

  public static func BuildPanel(
    canvas: ref<inkCanvas>,
    panel: ref<inkCanvas>,
    game: GameInstance,
    hudSystem: ref<MordeakCyberwareHUDSystem>,
    preview: ref<MordeakHUDPreview>
  ) -> Void {
    // Build the frame and heading, including the infection-only warning badge.
    let themeRectangles: array<wref<inkRectangle>>;
    let themeRectangleAlphas: array<Float>;
    let themeTexts: array<wref<inkText>>;
    let themeTextAlphas: array<Float>;
    let frameTop = MordeakCyberwareHUDSystem.CreateRectangle(
      panel,
      n"MordeakCyberwareHUDFrameTop",
      0.0,
      0.0,
      760.0,
      2.0,
      HDRColor(1.0, 0.0, 0.24, 1.0)
    );
    ArrayPush(themeRectangles, frameTop);
    ArrayPush(themeRectangleAlphas, 1.0);
    let frameBottom = MordeakCyberwareHUDSystem.CreateRectangle(
      panel, n"MordeakCyberwareHUDFrameBottom", 0.0, 708.0, 760.0, 2.0,
      HDRColor(1.0, 0.0, 0.24, 1.0)
    );
    ArrayPush(themeRectangles, frameBottom);
    ArrayPush(themeRectangleAlphas, 1.0);
    let frameLeft = MordeakCyberwareHUDSystem.CreateRectangle(
      panel, n"MordeakCyberwareHUDFrameLeft", 0.0, 2.0, 2.0, 706.0,
      HDRColor(1.0, 0.0, 0.24, 1.0)
    );
    ArrayPush(themeRectangles, frameLeft);
    ArrayPush(themeRectangleAlphas, 1.0);
    let frameRight = MordeakCyberwareHUDSystem.CreateRectangle(
      panel, n"MordeakCyberwareHUDFrameRight", 758.0, 2.0, 2.0, 706.0,
      HDRColor(1.0, 0.0, 0.24, 1.0)
    );
    ArrayPush(themeRectangles, frameRight);
    ArrayPush(themeRectangleAlphas, 1.0);
    let mainBackground = MordeakCyberwareHUDSystem.CreateRectangle(
      panel,
      n"MordeakCyberwareHUDBackground",
      2.0,
      2.0,
      756.0,
      706.0,
      HDRColor(0.0, 0.0, 0.0, 1.0)
    );
    if IsDefined(hudSystem) {
      hudSystem.m_mainBackground = mainBackground;
      let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
      if IsDefined(questsSystem) {
        hudSystem.OnHudBackgroundColorChanged(questsSystem.GetFact(n"mordeak_dollchip_hud_background_color"));
        hudSystem.OnHudOpacityChanged(questsSystem.GetFact(n"mordeak_dollchip_hud_opacity"));
      } else {
        hudSystem.m_backgroundOpacity = 1.0;
        hudSystem.UpdateBackgroundOpacity();
      }
    }

    let title = MordeakCyberwareHUDSystem.CreateText(
      panel,
      n"MordeakCyberwareHUDTitle",
      "DollChip / Bio-Monitor Firmware UMH",
      28.0,
      20.0,
      490.0,
      34.0,
      26,
      HDRColor(1.0, 0.0, 0.24, 1.0)
    );
    ArrayPush(themeTexts, title);
    ArrayPush(themeTextAlphas, 1.0);
    title.SetFontStyle(n"Semi-Bold");

    let statusBackground = MordeakCyberwareHUDSystem.CreateRectangle(
      panel,
      n"MordeakCyberwareHUDStatusBackground",
      548.0,
      20.0,
      184.0,
      34.0,
      HDRColor(1.0, 0.0, 0.24, 0.16)
    );
    statusBackground.SetVisible(false);
    let statusBadge = MordeakCyberwareHUDSystem.CreateText(
      panel,
      n"MordeakCyberwareHUDStatus",
      "SYSTEM NOMINAL",
      548.0,
      20.0,
      184.0,
      34.0,
      17,
      HDRColor(1.0, 0.0, 0.24, 1.0)
    );
    statusBadge.SetVisible(false);
    statusBadge.SetHAlign(inkEHorizontalAlign.Center);
    statusBadge.SetHorizontalAlignment(textHorizontalAlignment.Center);

    let headerDivider = MordeakCyberwareHUDSystem.CreateRectangle(
      panel,
      n"MordeakCyberwareHUDHeaderDivider",
      28.0,
      67.0,
      704.0,
      2.0,
      HDRColor(1.0, 0.0, 0.24, 0.45)
    );
    ArrayPush(themeRectangles, headerDivider);
    ArrayPush(themeRectangleAlphas, 0.45);

    let specsLeft = MordeakCyberwareHUDSystem.CreateText(
      panel,
      n"MordeakCyberwareHUDSpecsLeft",
      "",
      30.0,
      82.0,
      340.0,
      54.0,
      16,
      HDRColor(0.64, 0.70, 0.81, 1.0)
    );
    let specsRight = MordeakCyberwareHUDSystem.CreateText(
      panel,
      n"MordeakCyberwareHUDSpecsRight",
      "",
      390.0,
      82.0,
      340.0,
      54.0,
      16,
      HDRColor(0.64, 0.70, 0.81, 1.0)
    );
    let matrixTitle = MordeakCyberwareHUDSystem.CreateText(
      panel,
      n"MordeakCyberwareHUDMatrixTitle",
      "MORDEAK JOYWARE SUITE",
      390.0,
      148.0,
      340.0,
      26.0,
      19,
      HDRColor(1.0, 0.0, 0.24, 1.0)
    );
    ArrayPush(themeTexts, matrixTitle);
    ArrayPush(themeTextAlphas, 1.0);

    let telemetryTitle = MordeakCyberwareHUDSystem.CreateText(
      panel, n"MordeakCyberwareHUDTelemetryTitle", "RISK & YIELD TELEMETRY",
      30.0, 148.0, 340.0, 26.0, 19, HDRColor(1.0, 0.0, 0.24, 1.0)
    );
    ArrayPush(themeTexts, telemetryTitle);
    ArrayPush(themeTextAlphas, 1.0);

    let telemetryNames: array<String> = [
      "VD RISK", "TIP RANGE", "FAIL TO FIND", "BAD EVENTS", "PAYOUT BONUS"
    ];
    let telemetryValues: array<wref<inkText>>;
    let telemetryDetails: array<wref<inkText>>;
    let telemetryBars: array<wref<inkRectangle>>;
    let telemetryIndex: Int32 = 0;
    let telemetryY: Float = 180.0;
    while telemetryIndex < ArraySize(telemetryNames) {
      let telemetryColor: HDRColor = MordeakCyberwareHUDSystem.GetTelemetryColor(telemetryIndex);
      MordeakCyberwareHUDSystem.CreateRectangle(
        panel, StringToName("MordeakTelemetryRow" + ToString(telemetryIndex)),
        30.0, telemetryY, 340.0, 68.0, HDRColor(0.06, 0.08, 0.12, 0.72)
      );
      MordeakCyberwareHUDSystem.CreateRectangle(
        panel, StringToName("MordeakTelemetryAccent" + ToString(telemetryIndex)),
        30.0, telemetryY, 4.0, 68.0, telemetryColor
      );
      MordeakCyberwareHUDSystem.CreateText(
        panel, StringToName("MordeakTelemetryLabel" + ToString(telemetryIndex)),
        telemetryNames[telemetryIndex], 44.0, telemetryY + 3.0, 170.0, 28.0,
        17, HDRColor(0.85, 0.90, 0.96, 1.0)
      );
      let value = MordeakCyberwareHUDSystem.CreateText(
        panel, StringToName("MordeakTelemetryValue" + ToString(telemetryIndex)),
        "--", 213.0, telemetryY + 3.0, 141.0, 28.0, 18, telemetryColor
      );
      value.SetHAlign(inkEHorizontalAlign.Right);
      value.SetHorizontalAlignment(textHorizontalAlignment.Right);
      ArrayPush(telemetryValues, value);
      let detail = MordeakCyberwareHUDSystem.CreateText(
        panel, StringToName("MordeakTelemetryDetail" + ToString(telemetryIndex)),
        "", 44.0, telemetryY + 32.0, 310.0, 20.0, 12,
        HDRColor(0.64, 0.70, 0.81, 1.0)
      );
      ArrayPush(telemetryDetails, detail);
      MordeakCyberwareHUDSystem.CreateRectangle(
        panel, StringToName("MordeakTelemetryTrack" + ToString(telemetryIndex)),
        44.0, telemetryY + 57.0, 300.0, 4.0, HDRColor(0.20, 0.24, 0.30, 0.8)
      );
      let bar = MordeakCyberwareHUDSystem.CreateRectangle(
        panel, StringToName("MordeakTelemetryBar" + ToString(telemetryIndex)),
        44.0, telemetryY + 57.0, 0.0, 4.0, telemetryColor
      );
      ArrayPush(telemetryBars, bar);
      telemetryIndex += 1;
      telemetryY += 74.0;
    }

    let itemNames: array<String>;
    ArrayPush(itemNames, "RAWDOG");
    ArrayPush(itemNames, "VELVET TOUCH");
    ArrayPush(itemNames, "SMOOTH SKIN");
    ArrayPush(itemNames, "NEVERLOCK");
    ArrayPush(itemNames, "PLAYMATE");
    let itemValues: array<wref<inkText>>;
    let itemAccents: array<wref<inkRectangle>>;
    let itemIndex: Int32 = 0;
    let itemY: Float = 180.0;
    while itemIndex < ArraySize(itemNames) {
      MordeakCyberwareHUDSystem.CreateRectangle(
        panel,
        StringToName("MordeakCyberwareHUDItemRow" + ToString(itemIndex)),
        390.0,
        itemY,
        340.0,
        42.0,
        HDRColor(0.06, 0.08, 0.12, 0.72)
      );
      let accent = MordeakCyberwareHUDSystem.CreateRectangle(
        panel,
        StringToName("MordeakCyberwareHUDItemAccent" + ToString(itemIndex)),
        390.0,
        itemY,
        4.0,
        42.0,
        HDRColor(1.0, 0.0, 0.24, 1.0)
      );
      MordeakCyberwareHUDSystem.CreateText(
        panel,
        StringToName("MordeakCyberwareHUDItemLabel" + ToString(itemIndex)),
        itemNames[itemIndex],
        408.0,
        itemY + 4.0,
        164.0,
        34.0,
        17,
        HDRColor(0.64, 0.70, 0.81, 1.0)
      );
      let itemValue = MordeakCyberwareHUDSystem.CreateText(
        panel,
        StringToName("MordeakCyberwareHUDItemValue" + ToString(itemIndex)),
        "NOT INSTALLED",
        574.0,
        itemY + 4.0,
        140.0,
        34.0,
        17,
        HDRColor(0.35, 0.42, 0.54, 1.0)
      );
      itemValue.SetHAlign(inkEHorizontalAlign.Right);
      itemValue.SetHorizontalAlignment(textHorizontalAlignment.Right);
      ArrayPush(itemValues, itemValue);
      ArrayPush(itemAccents, accent);
      itemY += 48.0;
      itemIndex += 1;
    }

    // Add infection status and confidence values.
    let sicknessTitle = MordeakCyberwareHUDSystem.CreateText(
      panel,
      n"MordeakCyberwareHUDSicknessTitle",
      "VITALS > USER STATUS",
      390.0,
      430.0,
      340.0,
      26.0,
      19,
      HDRColor(1.0, 0.0, 0.24, 1.0)
    );
    ArrayPush(themeTexts, sicknessTitle);
    ArrayPush(themeTextAlphas, 1.0);
    MordeakCyberwareHUDSystem.CreateRectangle(
      panel,
      n"MordeakCyberwareHUDSicknessRow",
      390.0,
      462.0,
      340.0,
      42.0,
      HDRColor(0.06, 0.08, 0.12, 0.72)
    );
    let sicknessAccent = MordeakCyberwareHUDSystem.CreateRectangle(
      panel,
      n"MordeakCyberwareHUDSicknessAccent",
      390.0,
      462.0,
      4.0,
      42.0,
      HDRColor(1.0, 0.0, 0.24, 1.0)
    );
    MordeakCyberwareHUDSystem.CreateText(
      panel,
      n"MordeakCyberwareHUDSicknessLabel",
      "HEALTH MONITOR",
      408.0,
      466.0,
      164.0,
      34.0,
      17,
      HDRColor(0.64, 0.70, 0.81, 1.0)
    );
    let sicknessValue = MordeakCyberwareHUDSystem.CreateText(
      panel,
      n"MordeakCyberwareHUDSicknessValue",
      "CLEAN",
      574.0,
      466.0,
      140.0,
      34.0,
      17,
      HDRColor(1.0, 0.0, 0.24, 1.0)
    );
    sicknessValue.SetHAlign(inkEHorizontalAlign.Right);
    sicknessValue.SetHorizontalAlignment(textHorizontalAlignment.Right);

    MordeakCyberwareHUDSystem.CreateRectangle(
      panel,
      n"MordeakCyberwareHUDCountRow",
      390.0,
      510.0,
      340.0,
      42.0,
      HDRColor(0.06, 0.08, 0.12, 0.72)
    );
    let countAccent = MordeakCyberwareHUDSystem.CreateRectangle(
      panel,
      n"MordeakCyberwareHUDCountAccent",
      390.0,
      510.0,
      4.0,
      42.0,
      HDRColor(1.0, 0.0, 0.24, 0.55)
    );
    ArrayPush(themeRectangles, countAccent);
    ArrayPush(themeRectangleAlphas, 0.55);
    MordeakCyberwareHUDSystem.CreateText(
      panel,
      n"MordeakCyberwareHUDCountLabel",
      "CONFIDENCE RATE",
      408.0,
      514.0,
      164.0,
      34.0,
      17,
      HDRColor(0.64, 0.70, 0.81, 1.0)
    );
    let sicknessCount = MordeakCyberwareHUDSystem.CreateText(
      panel,
      n"MordeakCyberwareHUDCountValue",
      "--",
      574.0,
      514.0,
      140.0,
      34.0,
      17,
      HDRColor(1.0, 0.0, 0.24, 1.0)
    );
    sicknessCount.SetHAlign(inkEHorizontalAlign.Right);
    sicknessCount.SetHorizontalAlignment(textHorizontalAlignment.Right);

    // Add the diagnostic log and the Y-key hint.
    let logTitle = MordeakCyberwareHUDSystem.CreateText(
      panel,
      n"MordeakCyberwareHUDLogTitle",
      "DIAGNOSTIC LOG",
      30.0,
      562.0,
      700.0,
      24.0,
      16,
      HDRColor(1.0, 0.0, 0.24, 0.8)
    );
    ArrayPush(themeTexts, logTitle);
    ArrayPush(themeTextAlphas, 0.8);
    MordeakCyberwareHUDSystem.CreateRectangle(
      panel,
      n"MordeakCyberwareHUDLogBackground",
      30.0,
      590.0,
      700.0,
      60.0,
      HDRColor(0.0, 0.0, 0.0, 0.72)
    );
    let logWidget = MordeakCyberwareHUDSystem.CreateText(
      panel,
      n"MordeakCyberwareHUDLog",
      "",
      42.0,
      594.0,
      680.0,
      52.0,
      14,
      HDRColor(0.36, 0.45, 0.58, 1.0)
    );
    let footer = MordeakCyberwareHUDSystem.CreateText(
      panel,
      n"MordeakCyberwareHUDFooter",
      "HUD TOGGLE // PRESS Y TO OPEN / CLOSE",
      30.0,
      663.0,
      700.0,
      24.0,
      13,
      HDRColor(1.0, 0.0, 0.24, 0.42)
    );
    ArrayPush(themeTexts, footer);
    ArrayPush(themeTextAlphas, 0.42);

    let sicknessOverlay: array<wref<inkRectangle>>;

    if IsDefined(hudSystem) {
      hudSystem.RegisterWidgets(
        canvas, statusBadge, statusBackground, specsLeft, specsRight,
        itemValues, itemAccents, telemetryValues, telemetryDetails, telemetryBars,
        sicknessValue, sicknessCount, sicknessAccent,
        themeRectangles, themeRectangleAlphas, themeTexts, themeTextAlphas,
        sicknessOverlay, logWidget, game
      );
    } else {
      if IsDefined(preview) {
        preview.m_background = mainBackground;
        preview.m_themeRectangles = themeRectangles;
        preview.m_themeRectangleAlphas = themeRectangleAlphas;
        preview.m_themeTexts = themeTexts;
        preview.m_themeTextAlphas = themeTextAlphas;
        preview.m_sicknessAccent = sicknessAccent;
        preview.m_sicknessValue = sicknessValue;
        preview.m_sicknessCount = sicknessCount;
        specsLeft.SetText("SUBJECT: V // PLAYMATE: COMMON\nMORDEAK UNITS: 1 / 5");
        specsRight.SetText("NEURO-LINK: ONLINE\nINFECTION SEVERITY: N/A");
        logWidget.SetText("[SYSTEM] PlayMate monitor online.\n[NEGOTIABLE AFFECTION] Sickness: CLEAN // Confidence: N/A");
        sicknessCount.SetText("N/A");
        let previewIndex: Int32 = 0;
        while previewIndex < ArraySize(itemValues) {
          let previewTier: Int32 = previewIndex == 4 ? 1 : 0;
          let previewColor: HDRColor = MordeakCyberwareHUDSystem.GetTierColor(previewTier);
          itemValues[previewIndex].SetText(MordeakCyberwareHUDSystem.FormatTier(previewTier));
          itemValues[previewIndex].SetTintColor(previewColor);
          itemAccents[previewIndex].SetTintColor(previewColor);
          previewIndex += 1;
        }
        let previewValues: array<String> = ["50%", "10-30%", "40%", "35%", "+0%"];
        let previewDetails: array<String> = [
          "RAW VS CARRIER | BASE 50%",
          "BASE + VELVET | EXCL. CLIENT BONUS",
          "BASE 40% | SMOOTH SKIN",
          "BASE 35% - NEVERLOCK ONLY",
          "ALL JOYWARE TIERS | MAX +220%"
        ];
        let previewBars: array<Float> = [1.0, 0.6, 1.0, 0.35, 0.0];
        previewIndex = 0;
        while previewIndex < ArraySize(previewValues) {
          telemetryValues[previewIndex].SetText(previewValues[previewIndex]);
          telemetryDetails[previewIndex].SetText(previewDetails[previewIndex]);
          telemetryBars[previewIndex].SetSize(Vector2(300.0 * previewBars[previewIndex], 4.0));
          previewIndex += 1;
        }
      }
    }
  }
}

@addField(SettingsMainGameController)
private let m_mordeakHUDPreview: ref<MordeakHUDPreview>;

@addMethod(SettingsMainGameController)
public func MordeakCreateHUDPreview(parent: ref<inkCompoundWidget>, colorIndex: Int32, backgroundColorIndex: Int32, opacity: Int32) -> Void {
  if !IsDefined(parent) {
    FTLog("[MordeakTechnica] HUD preview parent is unavailable.");
    return;
  }

  let slot: ref<inkCanvas> = new inkCanvas();
  slot.SetName(n"MordeakHUDPreviewSlot");
  slot.SetSize(Vector2(494.0, 488.0));
  slot.SetInteractive(false);
  slot.Reparent(parent);
  MordeakCyberwareHUDSystem.CreateText(
    slot, n"MordeakHUDPreviewLabel", "HUD PREVIEW // SAMPLE DATA",
    0.0, 0.0, 494.0, 26.0, 16, HDRColor(0.64, 0.70, 0.81, 1.0)
  );

  let panel: ref<inkCanvas> = new inkCanvas();
  panel.SetName(n"MordeakHUDPreviewPanel");
  panel.SetSize(Vector2(760.0, 710.0));
  panel.SetAnchor(inkEAnchor.TopLeft);
  panel.SetAnchorPoint(Vector2(0.0, 0.0));
  panel.SetTranslation(Vector2(0.0, 26.0));
  panel.SetScale(Vector2(0.65, 0.65));
  panel.Reparent(slot);

  this.m_mordeakHUDPreview = new MordeakHUDPreview();
  MordeakCyberwareHUDSystem.BuildPanel(slot, panel, GetGameInstance(), null, this.m_mordeakHUDPreview);
  this.m_mordeakHUDPreview.Update(colorIndex, backgroundColorIndex, opacity);
}

@addMethod(SettingsMainGameController)
public func MordeakUpdateHUDPreview(colorIndex: Int32, backgroundColorIndex: Int32, opacity: Int32) -> Void {
  if IsDefined(this.m_mordeakHUDPreview) {
    this.m_mordeakHUDPreview.Update(colorIndex, backgroundColorIndex, opacity);
  }
}

// PlayerPuppet helpers provide a simple entry point for other scripts.
@addMethod(PlayerPuppet)
public func OpenMordeakCyberwareHUD() -> Bool {
  return MordeakCyberwareHUDSystem.Open(this);
}

@addMethod(PlayerPuppet)
public func CloseMordeakCyberwareHUD() -> Void {
  MordeakCyberwareHUDSystem.Close(this);
}

@addMethod(PlayerPuppet)
public func ToggleMordeakCyberwareHUD() -> Bool {
  return MordeakCyberwareHUDSystem.Toggle(this);
}

// Build the popup when the HUD controller initializes; Open() can also build it on demand.
@wrapMethod(NewHudPhoneGameController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();
  MordeakCyberwareHUDSystem.EnsureWidgets(this.GetPlayerControlledObject().GetGame());
  return result;
}
