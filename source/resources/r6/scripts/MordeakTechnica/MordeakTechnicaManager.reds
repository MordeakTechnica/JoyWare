module MordeakTechnica

@if(ModuleExists("CyberwareEx"))
public func IsCyberwareExAvailable() -> Bool = true

@if(!ModuleExists("CyberwareEx"))
public func IsCyberwareExAvailable() -> Bool = false

@if(ModuleExists("CyberwareEx.ExtendedMode"))
public func IsCyberwareExExtendedModeAvailable() -> Bool = true

@if(!ModuleExists("CyberwareEx.ExtendedMode"))
public func IsCyberwareExExtendedModeAvailable() -> Bool = false

public class MordeakCyberwareHUDInputListener {
  private let m_player: wref<PlayerPuppet>;

  public func Register(player: ref<PlayerPuppet>) -> Void {
    this.m_player = player;
    player.RegisterInputListener(this, n"MordeakCyberwareHUDToggle");
  }

  public func Unregister(player: ref<PlayerPuppet>) -> Void {
    if IsDefined(player) {
      player.UnregisterInputListener(this);
    }
    this.m_player = null;
  }

  protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    if Equals(ListenerAction.GetName(action), n"MordeakCyberwareHUDToggle")
      && ListenerAction.IsButtonJustPressed(action) {
      let player: wref<PlayerPuppet> = this.m_player;
      if IsDefined(player) && !player.IsInCombat() {
        MordeakCyberwareHUDSystem.Toggle(player);
      }
      return true;
    }
    return false;
  }
}

@addField(PlayerPuppet)
private let m_mordeakCyberwareHUDInputListener: ref<MordeakCyberwareHUDInputListener>;

public class MordeakInitCallback extends DelayCallback {
  public let m_player: wref<PlayerPuppet>;

  public func Call() -> Void {
    if IsDefined(this.m_player) {
      MordeakTechnicaManager.UpdateAllFacts(this.m_player);
    }
  }
}

public class MordeakTechnicaManager {

  public static func IsCyberwareExInstalled() -> Bool {
    return IsCyberwareExAvailable();
  }

  public static func IsCyberwareExExtendedMode() -> Bool {
    return IsCyberwareExExtendedModeAvailable();
  }

  public static func UpdateAllFacts(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) {
      return;
    }
    RawDogFact.SetFact(player);
    VelvetTouchFact.SetFact(player);
    SmoothSkinFact.SetFact(player);
    NeverLockFact.SetFact(player);
    DollChipFact.SetFact(player);
    MordeakCyberwareHUDSystem.RefreshForPlayer(player);
  }

  public static func OnCyberwareEquipped(player: ref<PlayerPuppet>, itemData: wref<gameItemData>) -> Void {
    if !IsDefined(player) || !IsDefined(itemData) {
      return;
    }

    let tdbid: TweakDBID = ItemID.GetTDBID(itemData.GetID());

    let dollChipTier: Int32 = DollChipFact.GetTierFromTDBID(tdbid);
    if dollChipTier > 0 {
      DollChipFact.SetFact(player);
      return;
    }
    
    let rawDogTier: Int32 = RawDogFact.GetTierFromTDBID(tdbid);
    if rawDogTier > 0 {
      RawDogFact.SetFactExplicit(player, rawDogTier);
      return;
    }

    let velvetTier: Int32 = VelvetTouchFact.GetTierFromTDBID(tdbid);
    if velvetTier > 0 {
      VelvetTouchFact.SetFactExplicit(player, velvetTier);
      return;
    }

    let smoothTier: Int32 = SmoothSkinFact.GetTierFromTDBID(tdbid);
    if smoothTier > 0 {
      SmoothSkinFact.SetFactExplicit(player, smoothTier);
      return;
    }

    let neverTier: Int32 = NeverLockFact.GetTierFromTDBID(tdbid);
    if neverTier > 0 {
      NeverLockFact.SetFactExplicit(player, neverTier);
      return;
    }
  }

  public static func OnCyberwareUnequipped(player: ref<PlayerPuppet>, itemData: wref<gameItemData>) -> Void {
    if !IsDefined(player) || !IsDefined(itemData) {
      return;
    }

    let tdbid: TweakDBID = ItemID.GetTDBID(itemData.GetID());

    let dollChipTier: Int32 = DollChipFact.GetTierFromTDBID(tdbid);
    if dollChipTier > 0 {
      DollChipFact.SetFact(player);
      return;
    }

    if RawDogFact.GetTierFromTDBID(tdbid) > 0 {
      RawDogFact.SetFactExplicit(player, 0);
      return;
    }

    if VelvetTouchFact.GetTierFromTDBID(tdbid) > 0 {
      VelvetTouchFact.SetFactExplicit(player, 0);
      return;
    }

    if SmoothSkinFact.GetTierFromTDBID(tdbid) > 0 {
      SmoothSkinFact.SetFactExplicit(player, 0);
      return;
    }

    if NeverLockFact.GetTierFromTDBID(tdbid) > 0 {
      NeverLockFact.SetFactExplicit(player, 0);
      return;
    }
  }
}

// -----------------------------------------------------------------------------
// Centralized Game Lifecycle & Ripperdoc Hooks
// -----------------------------------------------------------------------------

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  
  if !IsDefined(this.m_mordeakCyberwareHUDInputListener) {
    this.m_mordeakCyberwareHUDInputListener = new MordeakCyberwareHUDInputListener();
    this.m_mordeakCyberwareHUDInputListener.Register(this);
  }

  let callback: ref<MordeakInitCallback> = new MordeakInitCallback();
  callback.m_player = this;
  GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(callback, 0.5, false);

  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnDetach() -> Bool {
  if IsDefined(this.m_mordeakCyberwareHUDInputListener) {
    this.m_mordeakCyberwareHUDInputListener.Unregister(this);
    this.m_mordeakCyberwareHUDInputListener = null;
  }
  return wrappedMethod();
}

@wrapMethod(RipperDocGameController)
private final func EquipCyberware(itemData: wref<gameItemData>) -> Bool {
  let result: Bool = wrappedMethod(itemData);
  let player: ref<PlayerPuppet> = this.GetPlayerControlledObject() as PlayerPuppet;
  if IsDefined(player) && IsDefined(itemData) {
    MordeakTechnicaManager.OnCyberwareEquipped(player, itemData);
    MordeakCyberwareHUDSystem.RefreshForPlayer(player);
  }
  return result;
}

@wrapMethod(RipperDocGameController)
private final func UnequipCyberware(itemData: wref<gameItemData>, opt itemToEquip: wref<gameItemData>, opt skipRefresh: Bool) -> Bool {
  let result: Bool = wrappedMethod(itemData, itemToEquip, skipRefresh);
  let player: ref<PlayerPuppet> = this.GetPlayerControlledObject() as PlayerPuppet;
  if IsDefined(player) && IsDefined(itemData) {
    MordeakTechnicaManager.OnCyberwareUnequipped(player, itemData);
    MordeakCyberwareHUDSystem.RefreshForPlayer(player);
  }
  return result;
}

@wrapMethod(RipperDocGameController)
protected cb func OnUninitialize() -> Bool {
  let player: ref<PlayerPuppet> = this.GetPlayerControlledObject() as PlayerPuppet;
  if IsDefined(player) {
    MordeakTechnicaManager.UpdateAllFacts(player);
  }
  return wrappedMethod();
}

@addMethod(PlayerPuppet)
public func IsCyberwareExInstalled() -> Bool {
  return MordeakTechnicaManager.IsCyberwareExInstalled();
}

@addMethod(PlayerPuppet)
public func IsCyberwareExExtendedMode() -> Bool {
  return MordeakTechnicaManager.IsCyberwareExExtendedMode();
}


